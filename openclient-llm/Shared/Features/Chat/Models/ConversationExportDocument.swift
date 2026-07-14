//
//  ConversationExportDocument.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ConversationExportDocument: Codable, Equatable, Sendable {
    // MARK: - Supporting Types

    struct ExportedConversation: Codable, Equatable, Sendable {
        let conversation: Conversation
        let attachments: [ExportedAttachment]
    }

    struct ExportedAttachment: Codable, Equatable, Sendable {
        let messageId: UUID
        let attachmentId: UUID
        let data: String
    }

    // MARK: - Properties

    static let formatIdentifier = "com.artcc.openclient-llm.conversations"
    static let currentVersion = 1

    let format: String
    let version: Int
    let exportedAt: Date
    let conversations: [ExportedConversation]

    // MARK: - Init

    init(
        exportedAt: Date = Date(),
        conversations: [ExportedConversation]
    ) {
        format = Self.formatIdentifier
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.conversations = conversations
    }
}
