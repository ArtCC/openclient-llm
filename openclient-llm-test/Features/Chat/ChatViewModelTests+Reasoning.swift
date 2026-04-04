//
//  ChatViewModelTests+Reasoning.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Thinking / Reasoning Disclosure

@MainActor
extension ChatViewModelTests {
    func test_send_sendTapped_withReasoningChunks_populatesReasoningContent() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "deepseek-r1")])
        mockStreamMessage.chunks = [
            .reasoning("Let me think..."),
            .reasoning(" Step 1: analyze"),
            .token("The answer is 42.")
        ]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.inputChanged("What is the answer?"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertEqual(assistantMessage?.role, .assistant)
        XCTAssertEqual(assistantMessage?.content, "The answer is 42.")
        XCTAssertEqual(assistantMessage?.reasoningContent, "Let me think... Step 1: analyze")
    }

    func test_send_sendTapped_withoutReasoningChunks_leavesReasoningContentNil() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hello"), .token(" world")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.inputChanged("Hi"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertEqual(assistantMessage?.role, .assistant)
        XCTAssertEqual(assistantMessage?.content, "Hello world")
        XCTAssertNil(assistantMessage?.reasoningContent)
    }

    func test_applyStreamChunk_reasoning_accumulatesText() {
        // Given
        let messageId = UUID()
        let message = ChatMessage(id: messageId, role: .assistant, content: "")
        var state = ChatViewModel.LoadedState()
        state.messages = [message]

        // When
        sut.applyStreamChunk(.reasoning("First part"), to: &state, assistantMessageId: messageId)
        sut.applyStreamChunk(.reasoning(" second part"), to: &state, assistantMessageId: messageId)

        // Then
        XCTAssertEqual(state.messages[0].reasoningContent, "First part second part")
        XCTAssertEqual(state.messages[0].content, "")
    }

    func test_applyStreamChunk_reasoning_doesNotModifyContent() {
        // Given
        let messageId = UUID()
        let message = ChatMessage(id: messageId, role: .assistant, content: "Existing content")
        var state = ChatViewModel.LoadedState()
        state.messages = [message]

        // When
        sut.applyStreamChunk(.reasoning("Some reasoning"), to: &state, assistantMessageId: messageId)

        // Then
        XCTAssertEqual(state.messages[0].content, "Existing content")
        XCTAssertEqual(state.messages[0].reasoningContent, "Some reasoning")
    }
}
