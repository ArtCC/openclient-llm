//
//  DeleteConversationUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class DeleteConversationUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: DeleteConversationUseCase!
    private var mockRepository: MockConversationRepository!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockRepository = MockConversationRepository()
        sut = DeleteConversationUseCase(repository: mockRepository)
    }

    override func tearDown() async throws {
        sut = nil
        mockRepository = nil

        try await super.tearDown()
    }

    // MARK: - Tests — execute

    func test_execute_deletesFromRepository() throws {
        // Given
        let conversationId = UUID()
        let conversation = Conversation(
            id: conversationId,
            modelId: "gpt-4",
            messages: []
        )
        mockRepository.conversations = [conversation]

        // When
        try sut.execute(conversationId)

        // Then
        XCTAssertEqual(mockRepository.deletedIds, [conversationId])
        XCTAssertTrue(mockRepository.conversations.isEmpty)
    }

    func test_execute_withRepositoryError_throwsError() {
        // Given
        mockRepository.deleteError = NSError(domain: "test", code: 1)

        // When / Then
        XCTAssertThrowsError(try sut.execute(UUID()))
    }

    func test_execute_deletingNonexistentId_stillCallsRepository() throws {
        // Given
        let conversationId = UUID()
        mockRepository.conversations = []

        // When
        try sut.execute(conversationId)

        // Then
        XCTAssertEqual(mockRepository.deletedIds, [conversationId])
    }
}
