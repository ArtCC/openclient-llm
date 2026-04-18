//
//  ShareExtensionStore.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ShareExtensionStore

/// Read-side store used by the main app to retrieve the `ShareExtensionItem` payload
/// left by the Share Extension in the shared App Group container.
/// Designed to be called from `@MainActor` context (e.g. `HomeViewModel`).
enum ShareExtensionStore {
    // MARK: - Properties

    static let groupIdentifier = "group.com.artcc.openclient-llm"

    private static let pendingItemFileName = "share_pending.json"
    private static let attachmentsFolderName = "SharePending"

    // MARK: - Private

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }

    // MARK: - Public

    /// Deserialises and returns the pending `ShareExtensionItem`, or `nil` if none exists.
    static func load() throws -> ShareExtensionItem? {
        guard let container = containerURL else { return nil }
        let fileURL = container.appendingPathComponent(pendingItemFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ShareExtensionItem.self, from: data)
    }

    /// Returns the raw bytes for a given `attachment` from the App Group container.
    static func loadAttachmentData(_ attachment: ShareExtensionItem.Attachment) -> Data? {
        guard let container = containerURL else { return nil }
        let fileURL = container.appendingPathComponent(attachment.relativePath)
        return try? Data(contentsOf: fileURL)
    }

    /// Removes the pending item JSON and all attachment files from the App Group container.
    static func clear() {
        guard let container = containerURL else { return }
        let fileURL = container.appendingPathComponent(pendingItemFileName)
        try? FileManager.default.removeItem(at: fileURL)
        let folderURL = container.appendingPathComponent(attachmentsFolderName)
        try? FileManager.default.removeItem(at: folderURL)
    }

    /// Serialises `item` as JSON and writes it atomically to the App Group container.
    /// Used by AppIntents that run inside the main app process (e.g. `SendFileToChatIntent`).
    static func save(_ item: ShareExtensionItem) throws {
        guard let container = containerURL else { return }
        let data = try JSONEncoder().encode(item)
        try data.write(to: container.appendingPathComponent(pendingItemFileName), options: .atomic)
    }

    /// Copies raw attachment bytes to the `SharePending/` folder inside the App Group container.
    /// - Returns: The relative path stored in `ShareExtensionItem.Attachment.relativePath`.
    @discardableResult
    static func writeAttachmentData(_ data: Data, fileName: String) throws -> String {
        guard let container = containerURL else { return "" }
        let folderURL = container.appendingPathComponent(attachmentsFolderName)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        let ext = URL(fileURLWithPath: fileName).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let relativePath = "\(attachmentsFolderName)/\(uniqueName)"
        try data.write(to: container.appendingPathComponent(relativePath), options: .atomic)
        return relativePath
    }
}
