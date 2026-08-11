//
//  AttachmentFileResolver.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct AttachmentFileResolver {
    // MARK: - Properties

    private let fileManager: FileManager
    private let baseURL: URL

    // MARK: - Init

    init(fileManager: FileManager, baseURL: URL) {
        self.fileManager = fileManager
        self.baseURL = baseURL.standardizedFileURL
    }

    // MARK: - Resolve

    func resolve(relativePath: String) throws -> URL {
        let root = baseURL.appendingPathComponent("Attachments", isDirectory: true)
        let candidate = baseURL.appendingPathComponent(relativePath).standardizedFileURL
        guard isContained(candidate, in: root) else { throw CloudSyncError.invalidAttachmentPath }
        try rejectSymbolicLinks(relativePath: relativePath)
        guard isContained(candidate.resolvingSymlinksInPath(), in: root.resolvingSymlinksInPath()) else {
            throw CloudSyncError.invalidAttachmentPath
        }
        return candidate
    }

    func attachmentRoot() throws -> URL {
        try rejectSymbolicLinks(relativePath: "Attachments")
        return baseURL.appendingPathComponent("Attachments", isDirectory: true)
    }

    func conversationDirectory(_ conversationId: UUID) throws -> URL {
        let relativePath = "Attachments/\(conversationId.uuidString)"
        try rejectSymbolicLinks(relativePath: relativePath)
        return baseURL.appendingPathComponent(relativePath, isDirectory: true)
    }

    // MARK: - Private

    private func rejectSymbolicLinks(relativePath: String) throws {
        var currentURL = baseURL
        for component in (relativePath as NSString).pathComponents {
            currentURL.appendPathComponent(component)
            guard fileManager.fileExists(atPath: currentURL.path) else { continue }
            let values = try currentURL.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw CloudSyncError.invalidAttachmentPath }
        }
    }

    private func isContained(_ url: URL, in directory: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path + "/")
    }
}
