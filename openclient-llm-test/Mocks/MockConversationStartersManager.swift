//
//  MockConversationStartersManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

struct MockConversationStartersManager: ConversationStartersManagerProtocol, Sendable {
    // MARK: - Properties

    var starters: [ConversationStarter] = [
        ConversationStarter(icon: "lightbulb", text: "Starter 1"),
        ConversationStarter(icon: "pencil", text: "Starter 2"),
        ConversationStarter(icon: "globe", text: "Starter 3"),
        ConversationStarter(icon: "book", text: "Starter 4"),
    ]

    // MARK: - Public

    func randomStarters(count: Int = 4) -> [ConversationStarter] {
        Array(starters.prefix(count))
    }
}
