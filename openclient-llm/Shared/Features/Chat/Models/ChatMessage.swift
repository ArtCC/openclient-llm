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
    var webSearchResults: [LiteLLMSearchResult]?
    var toolCalls: [ToolCall]?
    var toolCallId: String?
    var toolName: String?
    var isFavourite: Bool

    enum Role: String, Sendable, Equatable, Codable {
        case user
        case assistant
        case system
        case tool
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        reasoningContent: String? = nil,
        timestamp: Date = Date(),
        attachments: [Attachment] = [],
        tokenUsage: TokenUsage? = nil,
        webSearchResults: [LiteLLMSearchResult]? = nil,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil,
        toolName: String? = nil,
        isFavourite: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.timestamp = timestamp
        self.attachments = attachments
        self.tokenUsage = tokenUsage
        self.webSearchResults = webSearchResults
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.isFavourite = isFavourite
    }
}

// MARK: - Attachment

extension ChatMessage {
    enum AttachmentType: String, Sendable, Equatable, Codable {
        case image
        case pdf
    }

    /// An attachment associated with a chat message.
    ///
    /// Binary data is stored on disk (via `AttachmentRepository`) and referenced here
    /// by `fileRelativePath`. The `data` property loads it from disk on demand and is
    /// intentionally excluded from `Codable` serialisation.
    struct Attachment: Identifiable, Equatable, Sendable, Codable {
        // MARK: - Properties

        let id: UUID
        let type: AttachmentType
        let fileName: String
        /// MIME type of the attachment (e.g. `"image/jpeg"`, `"application/pdf"`).
        let mimeType: String
        /// Path relative to `FileManager.documentDirectory`.
        /// e.g. `"Attachments/<conversationId>/<attachmentId>.jpg"`
        /// Empty string indicates a legacy attachment pending migration.
        let fileRelativePath: String

        // MARK: - Init

        init(
            id: UUID = UUID(),
            type: AttachmentType,
            fileName: String,
            mimeType: String,
            fileRelativePath: String
        ) {
            self.id = id
            self.type = type
            self.fileName = fileName
            self.mimeType = mimeType
            self.fileRelativePath = fileRelativePath
        }

        // MARK: - Decodable

        /// Custom decoder that tolerates legacy JSON format (pre-v2) where
        /// `fileRelativePath` and `mimeType` were absent and `data` held raw bytes.
        /// The `data` key is intentionally ignored; `AttachmentMigrationUseCase`
        /// handles extracting and persisting those bytes to disk.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            let decodedType = try container.decode(AttachmentType.self, forKey: .type)
            type = decodedType
            let decodedFileName = try container.decode(String.self, forKey: .fileName)
            fileName = decodedFileName
            mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
                ?? Self.inferMimeType(for: decodedType, fileName: decodedFileName)
            // Legacy attachments won't have this key; migration will populate it
            fileRelativePath = try container.decodeIfPresent(String.self, forKey: .fileRelativePath) ?? ""
        }

        // MARK: - Helpers

        static func inferMimeType(for type: AttachmentType, fileName: String) -> String {
            switch type {
            case .pdf: return "application/pdf"
            case .image:
                let ext = (fileName as NSString).pathExtension.lowercased()
                switch ext {
                case "png": return "image/png"
                case "gif": return "image/gif"
                case "webp": return "image/webp"
                default: return "image/jpeg"
                }
            }
        }
    }
}
