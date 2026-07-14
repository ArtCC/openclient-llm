//
//  Conversation.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum ConversationContextMetadataError: LocalizedError {
    case invalidContextWindow
    case inconsistentSummary
    case invalidSummaryCursor

    var errorDescription: String? {
        switch self {
        case .invalidContextWindow:
            String(localized: "The conversation context window must be greater than zero.")
        case .inconsistentSummary:
            String(localized: "The conversation summary and its cursor must both be present.")
        case .invalidSummaryCursor:
            String(localized: "The conversation summary cursor does not reference one of its messages.")
        }
    }
}

struct Conversation: Identifiable, Equatable, Sendable, Codable {
    // MARK: - Properties

    let id: UUID
    var title: String
    var modelId: String
    var systemPrompt: String
    var contextWindowTokens: Int?
    var contextSummary: String?
    var contextSummaryCursorMessageId: UUID?
    var messages: [ChatMessage]
    var modelParameters: ModelParameters
    var isPinned: Bool
    var tags: [String]
    var parentConversationId: UUID?
    var branchedFromMessageId: UUID?
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String = "",
        modelId: String,
        systemPrompt: String = "",
        contextWindowTokens: Int? = nil,
        contextSummary: String? = nil,
        contextSummaryCursorMessageId: UUID? = nil,
        messages: [ChatMessage] = [],
        modelParameters: ModelParameters = .default,
        isPinned: Bool = false,
        tags: [String] = [],
        parentConversationId: UUID? = nil,
        branchedFromMessageId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.modelId = modelId
        self.systemPrompt = systemPrompt
        self.contextWindowTokens = contextWindowTokens
        self.contextSummary = contextSummary
        self.contextSummaryCursorMessageId = contextSummaryCursorMessageId
        self.messages = messages
        self.modelParameters = modelParameters
        self.isPinned = isPinned
        self.tags = tags
        self.parentConversationId = parentConversationId
        self.branchedFromMessageId = branchedFromMessageId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        modelId = try container.decode(String.self, forKey: .modelId)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        contextWindowTokens = try container.decodeIfPresent(Int.self, forKey: .contextWindowTokens)
        contextSummary = try container.decodeIfPresent(String.self, forKey: .contextSummary)
        contextSummaryCursorMessageId = try container.decodeIfPresent(UUID.self, forKey: .contextSummaryCursorMessageId)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        modelParameters = try container.decodeIfPresent(ModelParameters.self, forKey: .modelParameters) ?? .default
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        parentConversationId = try container.decodeIfPresent(UUID.self, forKey: .parentConversationId)
        branchedFromMessageId = try container.decodeIfPresent(UUID.self, forKey: .branchedFromMessageId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    // MARK: - Computed

    var totalTokens: Int {
        messages.compactMap(\.tokenUsage?.totalTokens).reduce(0, +)
    }

    func contextPartition() -> (messages: [ChatMessage], compactedCount: Int) {
        guard let summary = contextSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty,
              let cursorMessageId = contextSummaryCursorMessageId,
              let cursorIndex = messages.firstIndex(where: { $0.id == cursorMessageId }) else {
            return (messages, 0)
        }
        return (Array(messages.dropFirst(cursorIndex + 1)), cursorIndex + 1)
    }

    func validateContextMetadata() throws {
        if let contextWindowTokens, contextWindowTokens <= 0 {
            throw ConversationContextMetadataError.invalidContextWindow
        }
        let summary = contextSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSummary = summary?.isEmpty == false
        guard hasSummary == (contextSummaryCursorMessageId != nil) else {
            throw ConversationContextMetadataError.inconsistentSummary
        }
        if let cursorMessageId = contextSummaryCursorMessageId {
            guard let cursorIndex = messages.firstIndex(where: { $0.id == cursorMessageId }) else {
                throw ConversationContextMetadataError.invalidSummaryCursor
            }
            if cursorIndex + 1 < messages.count, messages[cursorIndex + 1].role != .user {
                throw ConversationContextMetadataError.invalidSummaryCursor
            }
        }
    }
}
