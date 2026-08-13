//
//  SaveConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SaveConversationUseCaseProtocol: Sendable {
    @discardableResult
    func execute(_ conversation: Conversation, expectedBase: Conversation?) async throws -> Conversation
    func executeImportBatch(_ conversations: [Conversation]) async throws -> [Conversation]
}

extension SaveConversationUseCaseProtocol {
    @discardableResult
    func execute(_ conversation: Conversation) async throws -> Conversation {
        try await execute(conversation, expectedBase: nil)
    }
}

struct SaveConversationUseCase: SaveConversationUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    @discardableResult
    func execute(_ conversation: Conversation, expectedBase: Conversation?) async throws -> Conversation {
        let saved = try await repository.save(conversation, expectedBase: expectedBase)
        SpotlightManager.index(saved)
        return saved
    }

    func executeImportBatch(_ conversations: [Conversation]) async throws -> [Conversation] {
        let saved = try await repository.importBatch(conversations)
        saved.forEach(SpotlightManager.index)
        return saved
    }
}
