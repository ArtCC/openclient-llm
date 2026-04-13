//
//  RenameConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol RenameConversationUseCaseProtocol: Sendable {
    func execute(_ conversationId: UUID, newTitle: String) throws
}

struct RenameConversationUseCase: RenameConversationUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ conversationId: UUID, newTitle: String) throws {
        var conversations = try repository.loadAll()
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        conversations[index].updatedAt = Date()
        try repository.save(conversations[index])
    }
}
