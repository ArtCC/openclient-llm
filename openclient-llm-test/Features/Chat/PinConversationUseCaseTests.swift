//
//  PinConversationUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class PinConversationUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: PinConversationUseCase!
    private var mockRepository: MockConversationRepository!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockRepository = MockConversationRepository()
        sut = PinConversationUseCase(repository: mockRepository)
    }

    override func tearDown() async throws {
        sut = nil
        mockRepository = nil

        try await super.tearDown()
    }

    // MARK: - Tests — execute

    func test_execute_pinConversation_setsIsPinnedTrue() throws {
        // Given
        let conversation = Conversation(id: UUID(), modelId: "gpt-4", messages: [], isPinned: false)
        mockRepository.conversations = [conversation]

        // When
        try sut.execute(conversation.id, isPinned: true)

        // Then
        let saved = mockRepository.savedConversations.first
        XCTAssertNotNil(saved)
        XCTAssertTrue(saved?.isPinned ?? false)
    }

    func test_execute_unpinConversation_setsIsPinnedFalse() throws {
        // Given
        let conversation = Conversation(id: UUID(), modelId: "gpt-4", messages: [], isPinned: true)
        mockRepository.conversations = [conversation]

        // When
        try sut.execute(conversation.id, isPinned: false)

        // Then
        let saved = mockRepository.savedConversations.first
        XCTAssertNotNil(saved)
        XCTAssertFalse(saved?.isPinned ?? true)
    }

    func test_execute_pins_updatesUpdatedAt() throws {
        // Given
        let before = Date().addingTimeInterval(-3600)
        let conversation = Conversation(
            id: UUID(),
            modelId: "gpt-4",
            messages: [],
            updatedAt: before
        )
        mockRepository.conversations = [conversation]

        // When
        try sut.execute(conversation.id, isPinned: true)

        // Then
        let saved = mockRepository.savedConversations.first
        XCTAssertNotNil(saved)
        XCTAssertGreaterThan(saved?.updatedAt ?? .distantPast, before)
    }

    func test_execute_nonexistentId_doesNotSave() throws {
        // Given
        let randomId = UUID()
        mockRepository.conversations = []

        // When
        try sut.execute(randomId, isPinned: true)

        // Then
        XCTAssertTrue(mockRepository.savedConversations.isEmpty)
    }

    func test_execute_repositoryLoadError_throwsError() {
        // Given
        mockRepository.loadError = NSError(domain: "test", code: 1)

        // When / Then
        XCTAssertThrowsError(try sut.execute(UUID(), isPinned: true))
    }

    func test_execute_repositorySaveError_throwsError() throws {
        // Given
        let conversation = Conversation(id: UUID(), modelId: "gpt-4", messages: [])
        mockRepository.conversations = [conversation]
        mockRepository.saveError = NSError(domain: "test", code: 2)

        // When / Then
        XCTAssertThrowsError(try sut.execute(conversation.id, isPinned: true))
    }
}
