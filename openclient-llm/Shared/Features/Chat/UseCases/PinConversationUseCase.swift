//
//  PinConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol PinConversationUseCaseProtocol: Sendable {
    func execute(_ conversationId: UUID, isPinned: Bool) throws
}

struct PinConversationUseCase: PinConversationUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ conversationId: UUID, isPinned: Bool) throws {
        var conversations = try repository.loadAll()
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].isPinned = isPinned
        conversations[index].updatedAt = Date()
        try repository.save(conversations[index])
    }
}
