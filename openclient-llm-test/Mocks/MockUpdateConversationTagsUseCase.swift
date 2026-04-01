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
    var executedTags: [String]?
    var error: Error?

    // MARK: - Public

    func execute(_ conversationId: UUID, tags: [String]) throws {
        if let error { throw error }
        executedId = conversationId
        executedTags = tags
    }
}
