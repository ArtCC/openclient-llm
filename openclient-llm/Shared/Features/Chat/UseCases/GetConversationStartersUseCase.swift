//
//  GetConversationStartersUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol GetConversationStartersUseCaseProtocol: Sendable {
    func execute(count: Int) -> [ConversationStarter]
}

struct GetConversationStartersUseCase: GetConversationStartersUseCaseProtocol {
    // MARK: - Properties

    private let manager: ConversationStartersManagerProtocol

    // MARK: - Init

    init(manager: ConversationStartersManagerProtocol = ConversationStartersManager()) {
        self.manager = manager
    }

    // MARK: - Execute

    func execute(count: Int) -> [ConversationStarter] {
        manager.randomStarters(count: count)
    }
}
