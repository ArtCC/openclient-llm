//
//  SpotlightManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 06/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CoreSpotlight
import Foundation

nonisolated struct SpotlightManager: Sendable {
    // MARK: - Properties

    static let activityType: String = CSSearchableItemActionType
    static let activityIdentifierKey: String = CSSearchableItemActivityIdentifier

    private static let domainIdentifier = "com.artcc.openclient-llm.conversations"

    // MARK: - Public

    static func index(_ conversation: Conversation) {
        let id = conversation.id.uuidString

        let title: String
        if !conversation.title.isEmpty {
            title = conversation.title
        } else if let first = conversation.messages.first(where: { $0.role == .user }) {
            let preview = first.content.prefix(60)
            title = preview.count < first.content.count ? "\(preview)…" : String(preview)
        } else {
            title = String(localized: "New Chat")
        }

        var snippet: String?
        if let last = conversation.messages.last(where: { $0.role != .system }),
           !last.content.isEmpty {
            let truncated = last.content.prefix(160)
            snippet = truncated.count < last.content.count ? "\(truncated)…" : String(truncated)
        }

        Task.detached(priority: .background) {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = title
            attributeSet.contentDescription = snippet
            let item = CSSearchableItem(
                uniqueIdentifier: id,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            try? await CSSearchableIndex.default().indexSearchableItems([item])
        }
    }

    static func deindex(id: UUID) {
        let idString = id.uuidString
        Task.detached(priority: .background) {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [idString])
        }
    }
}
