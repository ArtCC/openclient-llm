//
//  RenameConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol RenameConversationUseCaseProtocol: Sendable {
    func execute(_ conversationId: UUID, newTitle: String) async throws
}

struct RenameConversationUseCase: RenameConversationUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ conversationId: UUID, newTitle: String) async throws {
        _ = try await repository.rename(conversationId, title: newTitle)
    }
}
