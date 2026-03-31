//
//  ChatViewModelTests+Persistence.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Conversation persistence

@MainActor
extension ChatViewModelTests {
    func test_send_sendTapped_createsConversation() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.tokens = ["Hello"]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hi"))

        // When
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedState.conversation)
        XCTAssertEqual(loadedState.conversation?.modelId, "gpt-4")
    }

    func test_send_sendTapped_persistsConversation() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.tokens = ["Response"]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))

        // When
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        XCTAssertFalse(mockSaveConversation.savedConversations.isEmpty)
    }

    func test_send_conversationLoaded_restoresMessages() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there!")
        ]
        let conversation = Conversation(
            modelId: "gpt-4",
            systemPrompt: "Be helpful",
            messages: messages
        )

        // When
        sut.send(.conversationLoaded(conversation))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.count, 2)
        XCTAssertEqual(loadedState.systemPrompt, "Be helpful")
        XCTAssertNotNil(loadedState.conversation)
    }

    // MARK: - Tests — System prompt

    func test_send_systemPromptChanged_updatesState() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.systemPromptChanged("You are a pirate"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.systemPrompt, "You are a pirate")
    }

    // MARK: - Tests — Attachments

    func test_send_attachmentAdded_addsToState() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "test.jpg",
            data: Data()
        )

        // When
        sut.send(.attachmentAdded(attachment))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.pendingAttachments.count, 1)
        XCTAssertEqual(loadedState.pendingAttachments.first?.fileName, "test.jpg")
    }

    func test_send_attachmentRemoved_removesFromState() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "test.jpg",
            data: Data()
        )
        sut.send(.attachmentAdded(attachment))

        // When
        sut.send(.attachmentRemoved(attachment.id))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.pendingAttachments.isEmpty)
    }

    func test_send_sendTapped_clearsAttachments() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.tokens = ["Response"]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let attachment = ChatMessage.Attachment(
            type: .image,
            fileName: "test.jpg",
            data: Data()
        )
        sut.send(.attachmentAdded(attachment))
        sut.send(.inputChanged("Describe this image"))

        // When
        sut.send(.sendTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.pendingAttachments.isEmpty)
        XCTAssertFalse(loadedState.messages.first(where: { $0.role == .user })?.attachments.isEmpty ?? true)
    }

    // MARK: - Tests — Conversation at init

    func test_init_withConversation_loadsConversationAfterModels() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4"), LLMModel(id: "llama3")]
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi!")
        ]
        let conversation = Conversation(
            modelId: "llama3",
            systemPrompt: "Be helpful",
            messages: messages
        )

        mockFetchModels.result = .success(models)
        sut = ChatViewModel(
            conversation: conversation,
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.count, 2)
        XCTAssertEqual(loadedState.conversation?.id, conversation.id)
        XCTAssertEqual(loadedState.selectedModel?.id, "llama3")
        XCTAssertEqual(loadedState.systemPrompt, "Be helpful")
        XCTAssertTrue(loadedState.conversationStarters.isEmpty)
    }

    func test_init_withConversation_loadsConversationEvenOnModelError() async throws {
        // Given
        let messages = [ChatMessage(role: .user, content: "Hello")]
        let conversation = Conversation(modelId: "gpt-4", messages: messages)

        mockFetchModels.result = .failure(APIError.serverUnreachable)
        sut = ChatViewModel(
            conversation: conversation,
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.count, 1)
        XCTAssertNotNil(loadedState.conversation)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    // MARK: - Tests — Conversation auto-title

    func test_send_sendTapped_setsConversationTitleFromFirstMessage() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.tokens = ["Response"]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("What is quantum computing?"))

        // When
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversation?.title, "What is quantum computing?")
    }
}
