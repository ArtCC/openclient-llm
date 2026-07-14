//
//  MockUpdateConversationTagsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockUpdateConversationTagsUseCase: UpdateConversationTagsUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var executedId: UUID?
    var executedTags: [ConversationTag]?
    var error: Error?

    // MARK: - Public

    func execute(_ conversationId: UUID, tags: [ConversationTag]) throws -> [ConversationTag] {
        if let error { throw error }
        executedId = conversationId
        executedTags = tags
        return tags
    }
}
