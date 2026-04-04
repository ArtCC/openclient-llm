//
//  BranchConversationUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class BranchConversationUseCaseTests: XCTestCase {
    // MARK: - Properties

    var sut: BranchConversationUseCase!
    var mockSave: MockSaveConversationUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        mockSave = MockSaveConversationUseCase()
        sut = BranchConversationUseCase(saveConversationUseCase: mockSave)
    }

    override func tearDown() async throws {
        sut = nil
        mockSave = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_createsNewConversationWithMessagesUpToAndIncludingTarget() throws {
        // Given
        let msg1 = ChatMessage(role: .user, content: "First")
        let msg2 = ChatMessage(role: .assistant, content: "Second")
        let msg3 = ChatMessage(role: .user, content: "Third")
        let conversation = Conversation(modelId: "gpt-4", messages: [msg1, msg2, msg3])

        // When — fork from msg2 (assistant)
        let fork = try sut.execute(conversation: conversation, fromMessageId: msg2.id)

        // Then
        XCTAssertEqual(fork.messages.count, 2)
        XCTAssertEqual(fork.messages.first?.content, "First")
        XCTAssertEqual(fork.messages.last?.content, "Second")
    }

    func test_execute_setsParentConversationId() throws {
        // Given
        let msg = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(modelId: "gpt-4", messages: [msg])

        // When
        let fork = try sut.execute(conversation: conversation, fromMessageId: msg.id)

        // Then
        XCTAssertEqual(fork.parentConversationId, conversation.id)
    }

    func test_execute_setsBranchedFromMessageId() throws {
        // Given
        let msg = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(modelId: "gpt-4", messages: [msg])

        // When
        let fork = try sut.execute(conversation: conversation, fromMessageId: msg.id)

        // Then
        XCTAssertEqual(fork.branchedFromMessageId, msg.id)
    }

    func test_execute_preservesModelAndSystemPrompt() throws {
        // Given
        let msg = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(
            modelId: "llama3",
            systemPrompt: "Be concise",
            messages: [msg]
        )

        // When
        let fork = try sut.execute(conversation: conversation, fromMessageId: msg.id)

        // Then
        XCTAssertEqual(fork.modelId, "llama3")
        XCTAssertEqual(fork.systemPrompt, "Be concise")
    }

    func test_execute_forkSavedToPersistence() throws {
        // Given
        let msg = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(modelId: "gpt-4", messages: [msg])

        // When
        _ = try sut.execute(conversation: conversation, fromMessageId: msg.id)

        // Then
        XCTAssertFalse(mockSave.savedConversations.isEmpty)
    }

    func test_execute_forkHasUniqueId() throws {
        // Given
        let msg = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(modelId: "gpt-4", messages: [msg])

        // When
        let fork = try sut.execute(conversation: conversation, fromMessageId: msg.id)

        // Then
        XCTAssertNotEqual(fork.id, conversation.id)
    }

    func test_execute_withUnknownMessageId_throwsError() throws {
        // Given
        let msg = ChatMessage(role: .user, content: "Hello")
        let conversation = Conversation(modelId: "gpt-4", messages: [msg])
        let unknownId = UUID()

        // When / Then
        XCTAssertThrowsError(try sut.execute(conversation: conversation, fromMessageId: unknownId)) { error in
            XCTAssertEqual(error as? BranchConversationError, .messageNotFound)
        }
    }

    func test_execute_forkFromLastMessage_includesAllMessages() throws {
        // Given
        let messages = (1...5).map { idx in
            ChatMessage(role: idx % 2 != 0 ? .user : .assistant, content: "Message \(idx)")
        }
        let conversation = Conversation(modelId: "gpt-4", messages: messages)
        let lastId = try XCTUnwrap(messages.last).id

        // When
        let fork = try sut.execute(conversation: conversation, fromMessageId: lastId)

        // Then
        XCTAssertEqual(fork.messages.count, 5)
    }

    func test_execute_forkFromFirstMessage_includesOnlyFirstMessage() throws {
        // Given
        let messages = [
            ChatMessage(role: .user, content: "First"),
            ChatMessage(role: .assistant, content: "Second"),
            ChatMessage(role: .user, content: "Third")
        ]
        let conversation = Conversation(modelId: "gpt-4", messages: messages)
        let firstId = try XCTUnwrap(messages.first).id

        // When
        let fork = try sut.execute(conversation: conversation, fromMessageId: firstId)

        // Then
        XCTAssertEqual(fork.messages.count, 1)
        XCTAssertEqual(fork.messages.first?.content, "First")
    }
}
