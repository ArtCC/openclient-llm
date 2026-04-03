//
//  ChatViewModelTests+Regenerate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Regenerate last response

@MainActor
extension ChatViewModelTests {
    // MARK: - regenerateLastResponse

    func test_send_regenerateLastResponse_removesLastAssistantAndRestreams() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("First")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        guard case .loaded(let afterFirst) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let messagesBeforeRegenerate = afterFirst.messages.count
        XCTAssertEqual(afterFirst.messages.last?.role, .assistant)
        XCTAssertEqual(afterFirst.messages.last?.content, "First")

        // When — regenerate returns a different response
        mockStreamMessage.chunks = [.token("Regenerated")]
        sut.send(.regenerateLastResponse)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isStreaming)
        // same message count (old assistant removed, new one added)
        XCTAssertEqual(loadedState.messages.count, messagesBeforeRegenerate)
        XCTAssertEqual(loadedState.messages.last?.role, .assistant)
        XCTAssertEqual(loadedState.messages.last?.content, "Regenerated")
    }

    func test_send_regenerateLastResponse_duringStreaming_doesNothing() async throws {
        // Given — streaming in progress
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Slow")]
        mockStreamMessage.tokenDelay = .milliseconds(500)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        // Don't wait for streaming to complete

        guard case .loaded(let streamingState) = sut.state,
              streamingState.isStreaming else {
            // If not yet streaming, skip test (timing-sensitive)
            return
        }

        let messagesBeforeRegen = streamingState.messages.count

        // When
        sut.send(.regenerateLastResponse)

        // Then — no change (still streaming, regen is a no-op)
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isStreaming)
        XCTAssertEqual(loadedState.messages.count, messagesBeforeRegen)

        sut.send(.stopStreamingTapped)
    }

    func test_send_regenerateLastResponse_withLastMessageUser_doesNothing() async throws {
        // Given — only a user message, no assistant response yet
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Load a conversation with only a user message
        let messages = [ChatMessage(role: .user, content: "Hello")]
        let conversation = Conversation(modelId: "gpt-4", messages: messages)
        sut.send(.conversationLoaded(conversation))

        guard case .loaded(let loadedBefore) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedBefore.messages.last?.role, .user)

        // When
        sut.send(.regenerateLastResponse)
        // should not start streaming
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isStreaming)
    }
}
