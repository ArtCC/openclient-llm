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

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.branchedConversation?.id, expectedFork.id)
        XCTAssertEqual(forkReceived?.id, expectedFork.id)
        XCTAssertFalse(mockBranchConversation.executedFromMessageIds.isEmpty)
        XCTAssertEqual(mockBranchConversation.executedFromMessageIds.first, msgId)
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
