//
//  SaveConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SaveConversationUseCaseProtocol: Sendable {
    func execute(_ conversation: Conversation) throws
}

struct SaveConversationUseCase: SaveConversationUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ conversation: Conversation) throws {
        try repository.save(conversation)
        SpotlightManager.index(conversation)
    }
}
