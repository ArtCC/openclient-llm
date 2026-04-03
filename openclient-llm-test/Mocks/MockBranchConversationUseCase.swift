//
//  MockBranchConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockBranchConversationUseCase: BranchConversationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var branchResult: Result<Conversation, Error>?
    var executedConversationIds: [UUID] = []
    var executedFromMessageIds: [UUID] = []

    // MARK: - Execute

    func execute(conversation: Conversation, fromMessageId: UUID) throws -> Conversation {
        executedConversationIds.append(conversation.id)
        executedFromMessageIds.append(fromMessageId)
        if let result = branchResult {
            return try result.get()
        }
        return Conversation(
            modelId: conversation.modelId,
            messages: Array(conversation.messages.prefix(
                (conversation.messages.firstIndex(where: { $0.id == fromMessageId }) ?? 0) + 1
            )),
            parentConversationId: conversation.id,
            branchedFromMessageId: fromMessageId
        )
    }
}
