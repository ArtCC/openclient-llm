//
//  ChatViewModelTests+Branching.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Conversation branching

@MainActor
extension ChatViewModelTests {
    // MARK: - forkFromMessage

    func test_send_forkFromMessage_withValidMessage_createsFork() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Response")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        guard case .loaded(let loadedAfterMessage) = sut.state,
              let msgId = loadedAfterMessage.messages.first(where: { $0.role == .user })?.id else {
            XCTFail("Expected loaded state with messages")
            return
        }

        let expectedFork = Conversation(
            modelId: "gpt-4",
            parentConversationId: loadedAfterMessage.conversation?.id
        )
        mockBranchConversation.branchResult = .success(expectedFork)

        var forkReceived: Conversation?
        sut.onForkCreated = { fork in forkReceived = fork }

        // When
        sut.send(.forkFromMessage(msgId))
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.branchedConversation?.id == expectedFork.id
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.branchedConversation?.id, expectedFork.id)
        XCTAssertEqual(forkReceived?.id, expectedFork.id)
        XCTAssertFalse(mockBranchConversation.executedFromMessageIds.isEmpty)
        XCTAssertEqual(mockBranchConversation.executedFromMessageIds.first, msgId)
        XCTAssertEqual(mockBranchConversation.executedConversations.first?.messages, loadedAfterMessage.messages)
    }

    func test_send_forkFromMessage_afterSendingMessage_usesCurrentHistory() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Response")]
        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            branchConversationUseCase: BranchConversationUseCase(
                saveConversationUseCase: mockSaveConversation
            ),
            getChatPreferencesUseCase: mockGetChatPreferences,
            getConversationStartersUseCase: mockGetConversationStarters
        )
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        guard case .loaded(let sentState) = sut.state,
              let userMessage = sentState.messages.first(where: { $0.role == .user }) else {
            XCTFail("Expected a sent user message")
            return
        }

        // When
        sut.send(.forkFromMessage(userMessage.id))
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.branchedConversation != nil
        }

        // Then
        guard case .loaded(let loadedState) = sut.state,
              let fork = loadedState.branchedConversation else {
            XCTFail("Expected a branched conversation")
            return
        }
        XCTAssertEqual(fork.messages.map(\.content), [userMessage.content])
        XCTAssertNotEqual(fork.messages.first?.id, userMessage.id)
        XCTAssertEqual(mockSaveConversation.savedConversations.last, fork)
    }

    func test_send_forkFromMessage_withoutConversation_doesNothing() async throws {
        // Given — no conversation loaded
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.forkFromMessage(UUID()))

        // Then
        XCTAssertTrue(mockBranchConversation.executedConversationIds.isEmpty)
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.branchedConversation)
    }

    func test_send_forkFromMessage_onError_setsErrorMessage() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Response")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        guard case .loaded(let loadedAfterMessage) = sut.state,
              let msgId = loadedAfterMessage.messages.first(where: { $0.role == .user })?.id else {
            XCTFail("Expected loaded state with messages")
            return
        }

        mockBranchConversation.branchResult = .failure(BranchConversationError.messageNotFound)

        // When
        sut.send(.forkFromMessage(msgId))
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.errorMessage != nil
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.branchedConversation)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    // MARK: - branchedConversationConsumed

    func test_send_branchedConversationConsumed_clearsBranchedConversation() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hi")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        guard case .loaded(let loaded) = sut.state,
              let msgId = loaded.messages.first(where: { $0.role == .user })?.id else {
            XCTFail("Expected loaded state with messages")
            return
        }

        let fork = Conversation(modelId: "gpt-4", parentConversationId: loaded.conversation?.id)
        mockBranchConversation.branchResult = .success(fork)
        sut.send(.forkFromMessage(msgId))
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.branchedConversation != nil
        }

        guard case .loaded(let withFork) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(withFork.branchedConversation)

        // When
        sut.send(.branchedConversationConsumed)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.branchedConversation)
    }
}
