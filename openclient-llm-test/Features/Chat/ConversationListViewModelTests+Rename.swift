//
//  ConversationListViewModelTests+Rename.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Rename

@MainActor
extension ConversationListViewModelTests {
    func test_send_titleEdited_updatesConversationTitleInState() async throws {
        // Given
        let conversation = Conversation(title: "Old Title", modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.titleEdited(conversation.id, "New Title"))

        // Then
        XCTAssertEqual(mockRenameConversation.capturedId, conversation.id)
        XCTAssertEqual(mockRenameConversation.capturedTitle, "New Title")

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.first?.title, "New Title")
    }

    func test_send_titleEdited_trimmesWhitespaceBeforeSaving() async throws {
        // Given
        let conversation = Conversation(title: "Old Title", modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.titleEdited(conversation.id, "  Trimmed  "))

        // Then
        XCTAssertEqual(mockRenameConversation.capturedTitle, "Trimmed")

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.first?.title, "Trimmed")
    }

    func test_send_titleEdited_withEmptyTitle_doesNotCallUseCase() async throws {
        // Given
        let conversation = Conversation(title: "Original", modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.titleEdited(conversation.id, "   "))

        // Then
        XCTAssertNil(mockRenameConversation.capturedId)
        XCTAssertNil(mockRenameConversation.capturedTitle)

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.first?.title, "Original")
    }

    func test_send_titleEdited_withRepositoryError_setsErrorMessage() async throws {
        // Given
        let conversation = Conversation(title: "Old Title", modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        mockRenameConversation.error = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Save failed"]
        )

        // When
        sut.send(.titleEdited(conversation.id, "New Title"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.errorMessage, "Save failed")
        // Title should remain unchanged on error
        XCTAssertEqual(loadedState.conversations.first?.title, "Old Title")
    }

    func test_send_titleEdited_withUnknownId_doesNothing() async throws {
        // Given
        let conversation = Conversation(title: "My Chat", modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When — send an ID that does not exist in state
        sut.send(.titleEdited(UUID(), "Irrelevant"))

        // Then
        XCTAssertNil(mockRenameConversation.capturedId)

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.first?.title, "My Chat")
    }
}
