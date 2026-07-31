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
    let isPinned: Bool

    // MARK: - Init

    init(
        id: UUID,
        title: String,
        modelId: String,
        lastMessagePreview: String,
        updatedAt: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.modelId = modelId
        self.lastMessagePreview = lastMessagePreview
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        modelId = try container.decode(String.self, forKey: .modelId)
        lastMessagePreview = try container.decode(String.self, forKey: .lastMessagePreview)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

private extension WidgetConversation {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case modelId
        case lastMessagePreview
        case updatedAt
        case isPinned
    }
}
