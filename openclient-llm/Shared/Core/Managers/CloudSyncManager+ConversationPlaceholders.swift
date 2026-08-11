//
//  CloudSyncManager+ConversationPlaceholders.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension CloudSyncManager {
    func requireNoPlaceholders(in files: [URL]) throws {
        let placeholders = files.filter { placeholderFileName(for: $0) != nil }
        for placeholder in placeholders {
            try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
        }
        if !placeholders.isEmpty {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    func requireDownloadedFile(at url: URL) throws {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
        if fileManager.fileExists(atPath: placeholder.path) {
            try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
            throw CloudSyncError.requiredDownloadPending
        }
        if fileManager.fileExists(atPath: url.path), try requiresDownload(at: url) {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    func dataIfPresent(at url: URL) throws -> Data? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func placeholderFileName(for url: URL) -> String? {
        let name = url.lastPathComponent
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return nil }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

    func requestAttachmentDirectories(
        in folders: [URL],
        requiredConversationIds: Set<UUID>
    ) throws {
        let placeholders = folders.compactMap { url -> (URL, UUID)? in
            guard let name = placeholderFileName(for: url), let id = UUID(uuidString: name) else { return nil }
            return (url, id)
        }
        for (url, _) in placeholders {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
        }
        guard !placeholders.contains(where: { requiredConversationIds.contains($0.1) }) else {
            throw CloudSyncError.requiredDownloadPending
        }
    }

    func loadAttachmentFolder(
        _ folder: URL,
        resolver: AttachmentFileResolver,
        dataByKey: inout [CloudAttachmentKey: Data],
        placeholders: inout Set<CloudAttachmentKey>
    ) throws -> UUID {
        let folderValues = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard folderValues.isDirectory == true,
              folderValues.isSymbolicLink != true,
              let conversationId = UUID(uuidString: folder.lastPathComponent) else {
            throw CloudSyncError.invalidAttachmentPath
        }
        _ = try resolver.conversationDirectory(conversationId)
        let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for url in files {
            try loadAttachmentFile(
                url,
                conversationId: conversationId,
                resolver: resolver,
                dataByKey: &dataByKey,
                placeholders: &placeholders
            )
        }
        return conversationId
    }

    func loadAttachmentFile(
        _ url: URL,
        conversationId: UUID,
        resolver: AttachmentFileResolver,
        dataByKey: inout [CloudAttachmentKey: Data],
        placeholders: inout Set<CloudAttachmentKey>
    ) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory != true else { throw CloudSyncError.invalidAttachmentPath }
        guard values.isSymbolicLink != true else { throw CloudSyncError.invalidAttachmentPath }
        let fileName = placeholderFileName(for: url) ?? url.lastPathComponent
        let key = CloudAttachmentKey(conversationId: conversationId, fileName: fileName)
        if placeholderFileName(for: url) != nil {
            placeholders.insert(key)
            try? fileManager.startDownloadingUbiquitousItem(at: url)
            return
        }
        let resolvedURL = try resolver.resolve(relativePath: ConversationAttachmentPath.relativePath(for: key))
        if try requiresDownload(at: resolvedURL) {
            placeholders.insert(key)
        } else {
            dataByKey[key] = try Data(contentsOf: resolvedURL)
        }
    }
}
