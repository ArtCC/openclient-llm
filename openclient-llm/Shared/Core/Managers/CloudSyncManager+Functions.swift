//
//  CloudSyncManager+Functions.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension CloudSyncManager {
    func cloudConversationsDirectory() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("Conversations", isDirectory: true)
    }

    func cloudAttachmentsDirectory() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("Attachments", isDirectory: true)
    }

    func cloudConversationTombstonesFileURL() -> URL? {
        cloudDocumentsDirectory()?.appendingPathComponent("ConversationTombstones.json")
    }

    func cloudConversationTombstonesDirectory() -> URL? {
        cloudDocumentsDirectory()?.appendingPathComponent("ConversationTombstones", isDirectory: true)
    }

    func cloudProfileFileURL() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("UserProfile.json")
    }

    func cloudTemplatesDirectory() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("PromptTemplates", isDirectory: true)
    }

    func cloudMemoryFileURL() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("Memory.json")
    }

    func cloudDocumentsDirectory() -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    func ensureDirectoryExists(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func writeIfChanged(_ data: Data, to url: URL) throws {
        if let existing = try? Data(contentsOf: url), existing == data { return }
        try data.write(to: url, options: .atomic)
    }

    func requiresDownload(at url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        guard values.ubiquitousItemDownloadingStatus != .current else { return false }
        try? fileManager.startDownloadingUbiquitousItem(at: url)
        return true
    }

    func tombstonesRequireDownload() throws -> Bool {
        if let legacyURL = cloudConversationTombstonesFileURL() {
            if try placeholderRequiresDownload(for: legacyURL) { return true }
            if fileManager.fileExists(atPath: legacyURL.path), try requiresDownload(at: legacyURL) {
                return true
            }
        }
        guard let directory = cloudConversationTombstonesDirectory(),
              fileManager.fileExists(atPath: directory.path) else {
            return false
        }
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let placeholders = files.filter { $0.lastPathComponent.hasPrefix(".") && $0.pathExtension == "icloud" }
        for placeholder in placeholders {
            try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
        }
        guard placeholders.isEmpty else { return true }
        return try files.filter { $0.pathExtension == "json" }.contains { try requiresDownload(at: $0) }
    }

    func placeholderRequiresDownload(for url: URL) throws -> Bool {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
        guard fileManager.fileExists(atPath: placeholder.path) else { return false }
        try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
        return true
    }

    func decodeTombstones(at url: URL) throws -> [ConversationTombstone] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ConversationTombstone].self, from: Data(contentsOf: url))
    }

    func decodeTombstone(at url: URL) throws -> ConversationTombstone {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ConversationTombstone.self, from: Data(contentsOf: url))
    }

    /// Copies attachment files referenced by `conversation` from local storage to iCloud.
    func syncAttachmentFiles(for conversation: Conversation, localDocuments: URL) throws {
        guard let cloudAttachments = cloudAttachmentsDirectory() else { return }

        // Collect all attachments from all messages
        let attachments = conversation.messages.flatMap { $0.attachments }
        guard !attachments.isEmpty else { return }

        let cloudConvFolder = cloudAttachments
            .appendingPathComponent(conversation.id.uuidString, isDirectory: true)
        try ensureDirectoryExists(at: cloudConvFolder)

        for attachment in attachments where !attachment.fileRelativePath.isEmpty {
            let localFile = localDocuments.appendingPathComponent(attachment.fileRelativePath)
            guard fileManager.fileExists(atPath: localFile.path) else { continue }

            let fileName = localFile.lastPathComponent
            let cloudFile = cloudConvFolder.appendingPathComponent(fileName)

            // Skip if already synced and same size (avoid unnecessary writes)
            if fileManager.fileExists(atPath: cloudFile.path) { continue }

            try fileManager.copyItem(at: localFile, to: cloudFile)
        }
    }
}
