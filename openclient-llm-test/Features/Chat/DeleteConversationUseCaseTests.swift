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

    func test_execute_deletesFromRepository() async throws {
        // Given
        let conversationId = UUID()
        let conversation = Conversation(
            id: conversationId,
            modelId: "gpt-4",
            messages: []
        )
        mockRepository.conversations = [conversation]

        // When
        try await sut.execute(conversationId)

        // Then
        XCTAssertEqual(mockRepository.deletedIds, [conversationId])
        XCTAssertTrue(mockRepository.conversations.isEmpty)
    }

    func test_execute_withRepositoryError_throwsError() async {
        // Given
        mockRepository.deleteError = NSError(domain: "test", code: 1)

        // When / Then
        do {
            try await sut.execute(UUID())
            XCTFail("Expected repository error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func test_execute_deletingNonexistentId_stillCallsRepository() async throws {
        // Given
        let conversationId = UUID()
        mockRepository.conversations = []

        // When
        try await sut.execute(conversationId)

        // Then
        XCTAssertEqual(mockRepository.deletedIds, [conversationId])
    }
}
