//
//  WidgetConversation.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - WidgetConversation

/// Lightweight snapshot of a conversation stored in the App Group container.
/// Used by WidgetKit extensions to display recent conversations without
/// access to the full document-directory storage.
struct WidgetConversation: Codable, Identifiable, Equatable, Sendable {
    // MARK: - Properties

    let id: UUID
    let title: String
    let modelId: String
    let lastMessagePreview: String
    let updatedAt: Date
}
