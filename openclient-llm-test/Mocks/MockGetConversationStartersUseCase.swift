//
//  MockGetConversationStartersUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

struct MockGetConversationStartersUseCase: GetConversationStartersUseCaseProtocol, Sendable {
    // MARK: - Properties

    var starters: [ConversationStarter] = [
        ConversationStarter(icon: "lightbulb", text: "Starter 1"),
        ConversationStarter(icon: "pencil", text: "Starter 2"),
        ConversationStarter(icon: "globe", text: "Starter 3"),
        ConversationStarter(icon: "book", text: "Starter 4"),
    ]

    // MARK: - GetConversationStartersUseCaseProtocol

    func execute(count: Int) -> [ConversationStarter] {
        Array(starters.prefix(count))
    }
}
