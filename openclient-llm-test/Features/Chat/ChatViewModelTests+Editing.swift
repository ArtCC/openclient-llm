//
//  ChatViewModelTests+Editing.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Message editing

@MainActor
extension ChatViewModelTests {
    // MARK: - editMessage

    func test_send_editMessage_updatesContentAndRemovesSubsequentMessages() async throws {
        // Given — conversation with user + assistant message
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("First response")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Original question"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        guard case .loaded(let afterFirst) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let userMsg = try XCTUnwrap(afterFirst.messages.first(where: { $0.role == .user }))
        let userMessageId = userMsg.id
        XCTAssertEqual(afterFirst.messages.count, 2)

        // When
        mockStreamMessage.chunks = [.token("New response")]
        sut.send(.editMessage(id: userMessageId, newContent: "Edited question"))
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isStreaming)
        XCTAssertEqual(loadedState.messages.count, 2)
        XCTAssertEqual(loadedState.messages.first?.content, "Edited question")
        XCTAssertEqual(loadedState.messages.last?.content, "New response")
    }

    func test_send_editMessage_withEmptyContent_doesNothing() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Response")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        guard case .loaded(let afterFirst) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let userMsg = try XCTUnwrap(afterFirst.messages.first(where: { $0.role == .user }))
        let userMessageId = userMsg.id
        let messageCount = afterFirst.messages.count

        // When
        sut.send(.editMessage(id: userMessageId, newContent: "   "))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isStreaming)
        XCTAssertEqual(loadedState.messages.count, messageCount)
    }

    func test_send_editMessage_duringStreaming_doesNothing() async throws {
        // Given — start streaming
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Response")]
        mockStreamMessage.tokenDelay = .milliseconds(500)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)

        guard case .loaded(let streamingState) = sut.state,
              streamingState.isStreaming else {
            return
        }

        let messageCount = streamingState.messages.count
        let userMsg = try XCTUnwrap(streamingState.messages.first(where: { $0.role == .user }))
        let userMsgId = userMsg.id

        // When
        sut.send(.editMessage(id: userMsgId, newContent: "Edited while streaming"))

        // Then — no change
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isStreaming)
        XCTAssertEqual(loadedState.messages.count, messageCount)

        sut.send(.stopStreamingTapped)
    }

    func test_send_editMessage_withNonUserMessage_doesNothing() async throws {
        // Given — load conversation with assistant message
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let assistantMsg = ChatMessage(role: .assistant, content: "Hello!")
        let conversation = Conversation(modelId: "gpt-4", messages: [assistantMsg])
        sut.send(.conversationLoaded(conversation))

        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }

        // When — try to edit assistant message
        sut.send(.editMessage(id: assistantMsg.id, newContent: "Hacked!"))

        // Then — no streaming started, messages unchanged
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isStreaming)
        XCTAssertEqual(loadedState.messages.first?.content, "Hello!")
        _ = loaded // suppress warning
    }

    func test_send_editMessage_removesAllMessagesAfterEditedOne() async throws {
        // Given — conversation with user, assistant, user, assistant (4 messages)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let firstUser = ChatMessage(role: .user, content: "First question")
        let firstAssist = ChatMessage(role: .assistant, content: "First answer")
        let secondUser = ChatMessage(role: .user, content: "Second question")
        let secondAssist = ChatMessage(role: .assistant, content: "Second answer")
        let conversation = Conversation(
            modelId: "gpt-4",
            messages: [firstUser, firstAssist, secondUser, secondAssist]
        )
        sut.send(.conversationLoaded(conversation))

        // When — edit the first user message
        mockStreamMessage.chunks = [.token("New first answer")]
        sut.send(.editMessage(id: firstUser.id, newContent: "Edited first question"))
        try await Task.sleep(for: .milliseconds(200))

        // Then — only firstUser (edited) + new assistant
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.count, 2)
        XCTAssertEqual(loadedState.messages.first?.content, "Edited first question")
        XCTAssertEqual(loadedState.messages.last?.content, "New first answer")
    }
}
