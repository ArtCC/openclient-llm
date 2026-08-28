//
//  ChatViewModelTests+ContextUsage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Context usage

@MainActor
extension ChatViewModelTests {
    func test_send_sendTapped_capturesTokenUsage() async throws {
        // Given
        let usage = TokenUsage(promptTokens: 10, completionTokens: 20, totalTokens: 30)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4", maxInputTokens: 1_000)])
        mockStreamMessage.chunks = [.token("Hello"), .usage(usage)]
        var didPersist = false
        sut.onConversationUpdated = { didPersist = true }
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hi"))

        // When
        sut.send(.sendTapped)
        await waitUntil { didPersist }

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
        XCTAssertEqual(loadedState.contextUsage?.estimatedInputTokens, 20)
    }

    func test_send_sendTapped_withoutPromptUsage_keepsEstimatedContext() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4", maxInputTokens: 1_000)])
        mockStreamMessage.chunks = [.token("Hello")]
        var didPersist = false
        sut.onConversationUpdated = { didPersist = true }
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded = self.sut.state else { return false }
            return true
        }
        sut.send(.inputChanged("Hi"))

        // When
        sut.send(.sendTapped)
        await waitUntil { didPersist }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.contextUsage?.estimatedInputTokens, 19)
    }

    func test_send_agentPromptUsage_calibratesContextAfterPersistence() async {
        // Given
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4", capabilities: [.functionCalling], maxInputTokens: 10_000)
        ])
        let viewModel = makeAgentViewModel(events: [.promptUsage(100), .token("Done")])
        var didPersist = false
        viewModel.onConversationUpdated = { didPersist = true }
        viewModel.send(.viewAppeared)
        await waitUntil {
            guard case .loaded = viewModel.state else { return false }
            return true
        }
        viewModel.send(.inputChanged("Hi"))

        // When
        viewModel.send(.sendTapped)
        await waitUntil { didPersist }

        // Then
        guard case .loaded(let loadedState) = viewModel.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.contextUsage?.estimatedInputTokens, 110)
    }

    func test_send_agentFinalRoundWithoutPromptUsage_usesEstimatedContext() async {
        // Given
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4", capabilities: [.functionCalling], maxInputTokens: 10_000)
        ])
        let viewModel = makeAgentViewModel(events: [.promptUsage(100), .promptUsage(nil), .token("Done")])
        var didPersist = false
        viewModel.onConversationUpdated = { didPersist = true }
        viewModel.send(.viewAppeared)
        await waitUntil {
            guard case .loaded = viewModel.state else { return false }
            return true
        }
        viewModel.send(.inputChanged("Hi"))

        // When
        viewModel.send(.sendTapped)
        await waitUntil { didPersist }

        // Then
        guard case .loaded(let loadedState) = viewModel.state else {
            XCTFail("Expected loaded state")
            return
        }
        var estimatedState = loadedState
        viewModel.refreshContextUsage(in: &estimatedState)
        XCTAssertEqual(loadedState.contextUsage, estimatedState.contextUsage)
    }

    func test_send_agentMemoryMutation_usesEstimatedContext() async {
        // Given
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4", capabilities: [.functionCalling], maxInputTokens: 10_000)
        ])
        let memoryCall = ToolCall(
            id: "memory-call",
            type: "function",
            function: ToolCallFunction(name: "save_memory", arguments: "{}")
        )
        let viewModel = makeAgentViewModel(events: [
            .promptUsage(100),
            .toolCallStarted(memoryCall),
            .toolCallCompleted(toolCallId: memoryCall.id, result: "Saved", searchResults: nil),
            .token("Done")
        ])
        var didPersist = false
        viewModel.onConversationUpdated = { didPersist = true }
        viewModel.send(.viewAppeared)
        await waitUntil {
            guard case .loaded = viewModel.state else { return false }
            return true
        }
        viewModel.send(.inputChanged("Remember this"))

        // When
        viewModel.send(.sendTapped)
        await waitUntil { didPersist }

        // Then
        guard case .loaded(let loadedState) = viewModel.state else {
            XCTFail("Expected loaded state")
            return
        }
        var estimatedState = loadedState
        viewModel.refreshContextUsage(in: &estimatedState)
        XCTAssertEqual(loadedState.contextUsage, estimatedState.contextUsage)
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
}

// MARK: - Helpers

private extension ChatViewModelTests {
    func makeAgentViewModel(events: [AgentEvent]) -> ChatViewModel {
        let mockAgent = MockAgentStreamUseCase()
        mockAgent.events = events
        return ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: mockAgent,
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            getChatPreferencesUseCase: mockGetChatPreferences,
            fetchMCPToolsUseCase: MockFetchMCPToolsUseCase(),
            getConversationStartersUseCase: mockGetConversationStarters,
            streamingBackgroundUseCase: MockStreamingBackgroundUseCase(),
            notifyStreamingCompletedUseCase: MockNotifyStreamingCompletedUseCase()
        )
    }
}
