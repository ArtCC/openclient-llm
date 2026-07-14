//
//  UpdateConversationTagsUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class UpdateConversationTagsUseCaseTests: XCTestCase {
    // MARK: - Tests

    func test_execute_existingTagName_reusesAssignedColor() throws {
        // Given
        let existing = Conversation(
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .blue)]
        )
        let target = Conversation(modelId: "gpt-4")
        let repository = MockConversationRepository()
        repository.conversations = [existing, target]
        let sut = UpdateConversationTagsUseCase(repository: repository)

        // When
        let tags = try sut.execute(
            target.id,
            tags: [ConversationTag(name: "swift", color: .red)]
        )

        // Then
        XCTAssertEqual(tags, [ConversationTag(name: "swift", color: .blue)])
        XCTAssertEqual(repository.savedConversations.first?.tags, tags)
    }
}
