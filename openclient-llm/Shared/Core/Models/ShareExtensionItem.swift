//
//  ShareExtensionItem.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ShareExtensionItem

/// Payload written to the shared App Group container by the Share Extension.
/// The main app reads this on launch to create a new conversation pre-populated
/// with the shared content. Must match the `ShareExtensionItem` definition in the
/// ShareExtension target so both targets produce compatible JSON.
struct ShareExtensionItem: Codable, Sendable {
    // MARK: - Attachment

    struct Attachment: Codable, Sendable {
        /// Original file name (e.g. `"photo.jpg"`, `"document.pdf"`).
        let fileName: String
        /// MIME type (e.g. `"image/jpeg"`, `"application/pdf"`).
        let mimeType: String
        /// Path relative to the App Group container root.
        /// e.g. `"SharePending/<uuid>.jpg"`
        let relativePath: String
    }

    // MARK: - Properties

    /// Optional plain-text content (user-typed or extracted from the shared item).
    let text: String?
    /// Optional URL string shared from Safari or another browser.
    let url: String?
    /// Binary attachments (images, PDFs). Actual bytes are stored at `relativePath`
    /// inside the App Group container.
    let attachments: [Attachment]
    let createdAt: Date
}
