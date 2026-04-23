//
//  ShareExtensionStore.swift
//  ShareExtension
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ShareExtensionStore

/// Write-side store used exclusively by the Share Extension to persist a pending
/// `ShareExtensionItem` into the shared App Group container.
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

    /// Serialises `item` as JSON and writes it atomically to the App Group container.
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
