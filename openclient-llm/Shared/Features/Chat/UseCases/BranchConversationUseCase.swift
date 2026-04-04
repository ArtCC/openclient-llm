//
//  BranchConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum BranchConversationError: LocalizedError {
    case messageNotFound

    var errorDescription: String? {
        switch self {
        case .messageNotFound:
            String(localized: "The message to fork from could not be found.")
        }
    }
}

protocol BranchConversationUseCaseProtocol: Sendable {
    func execute(conversation: Conversation, fromMessageId: UUID) throws -> Conversation
}

struct BranchConversationUseCase: BranchConversationUseCaseProtocol {
    // MARK: - Properties

    private let saveConversationUseCase: SaveConversationUseCaseProtocol

    // MARK: - Init

    init(saveConversationUseCase: SaveConversationUseCaseProtocol = SaveConversationUseCase()) {
        self.saveConversationUseCase = saveConversationUseCase
    }

    // MARK: - Execute

    func execute(conversation: Conversation, fromMessageId: UUID) throws -> Conversation {
        guard let messageIndex = conversation.messages.firstIndex(where: { $0.id == fromMessageId }) else {
            throw BranchConversationError.messageNotFound
        }

        let branchedMessages = Array(conversation.messages.prefix(messageIndex + 1))
        let fork = Conversation(
            modelId: conversation.modelId,
            systemPrompt: conversation.systemPrompt,
            messages: branchedMessages,
            modelParameters: conversation.modelParameters,
            isPinned: false,
            tags: conversation.tags,
            parentConversationId: conversation.id,
            branchedFromMessageId: fromMessageId
        )

        try saveConversationUseCase.execute(fork)
        return fork
    }
}
