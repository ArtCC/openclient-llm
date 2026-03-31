//
//  Conversation.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct Conversation: Identifiable, Equatable, Sendable, Codable {
    // MARK: - Properties

    let id: UUID
    var title: String
    var modelId: String
    var systemPrompt: String
    var messages: [ChatMessage]
    var modelParameters: ModelParameters
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String = "",
        modelId: String,
        systemPrompt: String = "",
        messages: [ChatMessage] = [],
        modelParameters: ModelParameters = .default,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.modelId = modelId
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.modelParameters = modelParameters
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        modelId = try container.decode(String.self, forKey: .modelId)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        modelParameters = try container.decodeIfPresent(ModelParameters.self, forKey: .modelParameters) ?? .default
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    // MARK: - Computed

    var totalTokens: Int {
        messages.compactMap(\.tokenUsage?.totalTokens).reduce(0, +)
    }
}
