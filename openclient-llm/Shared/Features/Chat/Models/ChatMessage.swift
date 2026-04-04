//
//  ChatMessage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ChatMessage: Identifiable, Equatable, Sendable, Codable {
    // MARK: - Properties

    let id: UUID
    let role: Role
    var content: String
    var reasoningContent: String?
    let timestamp: Date
    var attachments: [Attachment]
    var tokenUsage: TokenUsage?

    enum Role: String, Sendable, Equatable, Codable {
        case user
        case assistant
        case system
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        reasoningContent: String? = nil,
        timestamp: Date = Date(),
        attachments: [Attachment] = [],
        tokenUsage: TokenUsage? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.timestamp = timestamp
        self.attachments = attachments
        self.tokenUsage = tokenUsage
    }
}

// MARK: - Attachment

extension ChatMessage {
    enum AttachmentType: String, Sendable, Equatable, Codable {
        case image
        case pdf
    }

    struct Attachment: Identifiable, Equatable, Sendable, Codable {
        // MARK: - Properties

        let id: UUID
        let type: AttachmentType
        let fileName: String
        let data: Data

        // MARK: - Init

        init(
            id: UUID = UUID(),
            type: AttachmentType,
            fileName: String,
            data: Data
        ) {
            self.id = id
            self.type = type
            self.fileName = fileName
            self.data = data
        }
    }
}
