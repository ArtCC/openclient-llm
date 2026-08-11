//
//  UpdateConversationTagsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol UpdateConversationTagsUseCaseProtocol: Sendable {
    @discardableResult
    func execute(_ conversationId: UUID, tags: [ConversationTag]) async throws -> [ConversationTag]
}

struct UpdateConversationTagsUseCase: UpdateConversationTagsUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    @discardableResult
    func execute(_ conversationId: UUID, tags: [ConversationTag]) async throws -> [ConversationTag] {
        try await repository.updateTags(conversationId, tags: tags)?.tags ?? []
    }
}
