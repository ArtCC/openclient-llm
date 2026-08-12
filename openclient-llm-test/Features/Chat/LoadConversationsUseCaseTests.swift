//
//  LoadConversationsUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class LoadConversationsUseCaseTests: XCTestCase {
    // MARK: - Tests

    func test_execute_sameTagWithDifferentColors_usesFirstAssignedColor() async throws {
        // Given
        let first = Conversation(
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .blue)]
        )
        let second = Conversation(
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .red)]
        )
        let repository = MockConversationRepository()
        repository.conversations = [first, second]
        let sut = LoadConversationsUseCase(repository: repository)

        // When
        let conversations = try await sut.execute()

        // Then
        XCTAssertEqual(conversations.map(\.tags.first?.color), [.blue, .blue])
    }
}
