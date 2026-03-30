//
//  ChatMessage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ChatMessage: Identifiable, Equatable, Sendable {
    // MARK: - Properties

    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    enum Role: String, Sendable, Equatable {
        case user
        case assistant
        case system
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
