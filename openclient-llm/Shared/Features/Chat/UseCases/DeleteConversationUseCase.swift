//
//  DeleteConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol DeleteConversationUseCaseProtocol: Sendable {
    func execute(_ conversationId: UUID) throws
}

struct DeleteConversationUseCase: DeleteConversationUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ conversationId: UUID) throws {
        try repository.delete(conversationId)
    }
}
