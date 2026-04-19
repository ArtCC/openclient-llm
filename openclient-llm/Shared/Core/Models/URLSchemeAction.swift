//
//  URLSchemeAction.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - URLSchemeAction

/// Represents a parsed `openclient://` deep-link action.
///
/// Supported URLs:
/// - `openclient://chat?text=Hello`        — open a new chat pre-filled with text
/// - `openclient://chat?url=https://...`   — open a new chat pre-filled with a URL
/// - `openclient://conversation?id=<UUID>` — open an existing conversation by ID
enum URLSchemeAction: Equatable, Sendable {
    /// Open a new conversation with optional pre-filled text or URL.
    case chat(text: String?, url: String?)
    /// Open an existing conversation by its UUID.
    case conversation(id: UUID)
}
