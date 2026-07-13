//
//  MockSaveConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSaveConversationUseCase: SaveConversationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var savedConversations: [Conversation] = []
    var error: Error?
    var failureAtCall: Int?
    var executeCallCount = 0

    // MARK: - Execute

    func execute(_ conversation: Conversation) throws {
        executeCallCount += 1
        if let error { throw error }
        if failureAtCall == executeCallCount {
            throw NSError(domain: "MockSaveConversationUseCase", code: 1)
        }
        savedConversations.append(conversation)
    }
}
