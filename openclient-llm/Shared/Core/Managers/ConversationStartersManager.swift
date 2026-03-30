//
//  ConversationStartersManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ConversationStartersManagerProtocol: Sendable {
    func randomStarters(count: Int) -> [ConversationStarter]
}

struct ConversationStarter: Equatable, Sendable, Identifiable {
    // MARK: - Properties

    let icon: String
    let text: String

    var id: String { text }
}

struct ConversationStartersManager: ConversationStartersManagerProtocol, Sendable {
    // MARK: - Properties

    private let allStarters: [ConversationStarter] = [
        ConversationStarter(
            icon: "lightbulb",
            text: String(localized: "Explain a complex topic simply")
        ),
        ConversationStarter(
            icon: "pencil.and.outline",
            text: String(localized: "Write a creative story")
        ),
        ConversationStarter(
            icon: "chevron.left.forwardslash.chevron.right",
            text: String(localized: "Help me with my code")
        ),
        ConversationStarter(
            icon: "globe",
            text: String(localized: "Translate text to another language")
        ),
        ConversationStarter(
            icon: "book",
            text: String(localized: "Summarize a long text")
        ),
        ConversationStarter(
            icon: "questionmark.bubble",
            text: String(localized: "Answer a tricky question")
        ),
        ConversationStarter(
            icon: "text.badge.checkmark",
            text: String(localized: "Review and improve my writing")
        ),
        ConversationStarter(
            icon: "brain.head.profile",
            text: String(localized: "Brainstorm ideas for a project")
        ),
    ]

    // MARK: - Public

    func randomStarters(count: Int = 4) -> [ConversationStarter] {
        Array(allStarters.shuffled().prefix(count))
    }
}
