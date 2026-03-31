//
//  LoadConversationsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol LoadConversationsUseCaseProtocol: Sendable {
    func execute() throws -> [Conversation]
}

struct LoadConversationsUseCase: LoadConversationsUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute() throws -> [Conversation] {
        try repository.loadAll()
    }
}
