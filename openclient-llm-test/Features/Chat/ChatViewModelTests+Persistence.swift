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
        mockStreamMessage.chunks = [.token("Hello")]
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
        mockStreamMessage.chunks = [.token("Response")]
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
        mockStreamMessage.chunks = [.token("Response")]
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
            getChatPreferencesUseCase: mockGetChatPreferences,
            getConversationStartersUseCase: mockGetConversationStarters
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
            getChatPreferencesUseCase: mockGetChatPreferences,
            getConversationStartersUseCase: mockGetConversationStarters
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
        mockStreamMessage.chunks = [.token("Response")]
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

    // MARK: - Tests — Token usage

    func test_send_sendTapped_capturesTokenUsage() async throws {
        // Given
        let usage = TokenUsage(promptTokens: 10, completionTokens: 20, totalTokens: 30)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hello"), .usage(usage)]
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
        let assistantMessage = loadedState.messages.first(where: { $0.role == .assistant })
        XCTAssertNotNil(assistantMessage?.tokenUsage)
        XCTAssertEqual(assistantMessage?.tokenUsage?.totalTokens, 30)
        XCTAssertEqual(assistantMessage?.tokenUsage?.promptTokens, 10)
        XCTAssertEqual(assistantMessage?.tokenUsage?.completionTokens, 20)
    }

    func test_conversation_totalTokens_sumsAllMessages() {
        // Given
        let messages = [
            ChatMessage(role: .user, content: "Hi"),
            ChatMessage(
                role: .assistant,
                content: "Hello!",
                tokenUsage: TokenUsage(promptTokens: 5, completionTokens: 10, totalTokens: 15)
            ),
            ChatMessage(role: .user, content: "How are you?"),
            ChatMessage(
                role: .assistant,
                content: "I'm good!",
                tokenUsage: TokenUsage(promptTokens: 8, completionTokens: 12, totalTokens: 20)
            )
        ]
        let conversation = Conversation(modelId: "gpt-4", messages: messages)

        // Then
        XCTAssertEqual(conversation.totalTokens, 35)
    }

    // MARK: - Tests — Model parameters

    func test_send_modelParametersChanged_updatesState() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        let parameters = ModelParameters(temperature: 0.5, maxTokens: 2048, topP: 0.9)
        sut.send(.modelParametersChanged(parameters))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.modelParameters.temperature, 0.5)
        XCTAssertEqual(loadedState.modelParameters.maxTokens, 2048)
        XCTAssertEqual(loadedState.modelParameters.topP, 0.9)
    }

    func test_send_modelParametersChanged_persistsConversation() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hello")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Create a conversation first
        sut.send(.inputChanged("Hi"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        let savedCountBefore = mockSaveConversation.savedConversations.count

        // When
        let parameters = ModelParameters(temperature: 1.2)
        sut.send(.modelParametersChanged(parameters))

        // Then
        XCTAssertGreaterThan(mockSaveConversation.savedConversations.count, savedCountBefore)
        let lastSaved = mockSaveConversation.savedConversations.last
        XCTAssertEqual(lastSaved?.modelParameters.temperature, 1.2)
    }

    func test_send_conversationLoaded_restoresModelParameters() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let parameters = ModelParameters(temperature: 0.3, maxTokens: 1024)
        let conversation = Conversation(
            modelId: "gpt-4",
            modelParameters: parameters
        )

        // When
        sut.send(.conversationLoaded(conversation))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.modelParameters.temperature, 0.3)
        XCTAssertEqual(loadedState.modelParameters.maxTokens, 1024)
    }

    func test_modelParameters_default_hasNoCustomValues() {
        // Given
        let parameters = ModelParameters.default

        // Then
        XCTAssertFalse(parameters.hasCustomValues)
        XCTAssertNil(parameters.temperature)
        XCTAssertNil(parameters.maxTokens)
        XCTAssertNil(parameters.topP)
    }

    func test_modelParameters_withValues_hasCustomValues() {
        // Given
        let parameters = ModelParameters(temperature: 0.7)

        // Then
        XCTAssertTrue(parameters.hasCustomValues)
    }
}
