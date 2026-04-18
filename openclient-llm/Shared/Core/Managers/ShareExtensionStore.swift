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
}
