//
//  MemoryItem.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct MemoryItem: Identifiable, Equatable, Sendable, Codable {
    // MARK: - Properties

    enum Source: String, Codable, Sendable, Equatable {
        case user
        case model
    }

    let id: UUID
    var content: String
    var isEnabled: Bool
    let createdAt: Date
    let source: Source
    var updatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        content: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        source: Source = .user,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.source = source
        self.updatedAt = updatedAt ?? createdAt
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case isEnabled
        case createdAt
        case source
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        source = try container.decode(Source.self, forKey: .source)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(source, forKey: .source)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
