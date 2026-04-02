//
//  UpdateConversationTagsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol UpdateConversationTagsUseCaseProtocol: Sendable {
    func execute(_ conversationId: UUID, tags: [String]) throws
}

struct UpdateConversationTagsUseCase: UpdateConversationTagsUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ conversationId: UUID, tags: [String]) throws {
        var conversations = try repository.loadAll()
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].tags = tags.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        conversations[index].updatedAt = Date()
        try repository.save(conversations[index])
    }
}
