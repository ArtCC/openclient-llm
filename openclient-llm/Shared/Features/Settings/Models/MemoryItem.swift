//
//  MemoryItem.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct MemoryItem: Identifiable, Equatable, Sendable, Codable {
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

    // MARK: - Init

    init(
        id: UUID = UUID(),
        content: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        source: Source = .user
    ) {
        self.id = id
        self.content = content
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.source = source
    }
}
