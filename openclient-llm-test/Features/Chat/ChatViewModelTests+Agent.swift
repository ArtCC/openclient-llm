//
//  ChatViewModelTests+Agent.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Agent Mode

@MainActor
extension ChatViewModelTests {
    func test_sendMessage_withFunctionCallingModel_andWebSearch_usesAgentUseCase() async throws {
        // Given
        let mockAgent = MockAgentStreamUseCase()
        mockAgent.events = [.token("Agent answer")]
        let modelWithFunctionCalling = LLMModel(id: "gpt-4", capabilities: [.functionCalling])
        mockFetchModels.result = .success([modelWithFunctionCalling])

        let sutWithAgent = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: mockAgent,
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sutWithAgent.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Enable web search
        sutWithAgent.send(.webSearchToggled)
        sutWithAgent.send(.inputChanged("search something"))

        // When
        sutWithAgent.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sutWithAgent.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessages = loadedState.messages.filter { $0.role == .assistant }
        XCTAssertFalse(assistantMessages.isEmpty)
        let lastAssistant = assistantMessages.last
        XCTAssertEqual(lastAssistant?.content, "Agent answer")
    }

    func test_sendMessage_withFunctionCallingModel_webSearchDisabled_usesRegularStreaming() async throws {
        // Given
        let mockAgent = MockAgentStreamUseCase()
        mockAgent.events = [.token("Should not appear")]
        mockStreamMessage.chunks = [.token("Regular response")]
        let modelWithFunctionCalling = LLMModel(id: "gpt-4", capabilities: [.functionCalling])
        mockFetchModels.result = .success([modelWithFunctionCalling])

        let sutWithAgent = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: mockAgent,
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sutWithAgent.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Web search NOT enabled
        sutWithAgent.send(.inputChanged("regular message"))

        // When
        sutWithAgent.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sutWithAgent.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessages = loadedState.messages.filter { $0.role == .assistant }
        XCTAssertFalse(assistantMessages.isEmpty)
        let lastAssistant = assistantMessages.last
        XCTAssertEqual(lastAssistant?.content, "Regular response")
    }

    func test_sendMessage_noFunctionCallingModel_andWebSearch_usesContextInjection() async throws {
        // Given — model without functionCalling capability
        let mockAgent = MockAgentStreamUseCase()
        mockAgent.events = [.token("Should not appear")]
        mockStreamMessage.chunks = [.token("Context-injected response")]
        mockWebSearch.result = .success([
            LiteLLMSearchResult(title: "Result", url: "https://example.com", snippet: "Test snippet", date: nil)
        ])
        let modelWithoutFunctionCalling = LLMModel(id: "llama3", capabilities: [])
        mockFetchModels.result = .success([modelWithoutFunctionCalling])

        let sutWithAgent = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: mockAgent,
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sutWithAgent.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Enable web search
        sutWithAgent.send(.webSearchToggled)
        sutWithAgent.send(.inputChanged("news about AI"))

        // When
        sutWithAgent.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then — uses regular streaming (context injection), NOT agent
        guard case .loaded(let loadedState) = sutWithAgent.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessages = loadedState.messages.filter { $0.role == .assistant }
        XCTAssertFalse(assistantMessages.isEmpty)
        let lastAssistant = assistantMessages.last
        XCTAssertEqual(lastAssistant?.content, "Context-injected response")
    }

    func test_applyAgentEvent_token_appendsToAssistantMessage() {
        // Given
        let assistantId = UUID()
        var loadedState = ChatViewModel.LoadedState()
        loadedState.messages = [ChatMessage(id: assistantId, role: .assistant, content: "")]

        // When
        let viewModel = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: MockAgentStreamUseCase(),
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )
        viewModel.applyAgentEvent(.token("Hello "), to: &loadedState, assistantMessageId: assistantId)
        viewModel.applyAgentEvent(.token("world"), to: &loadedState, assistantMessageId: assistantId)

        // Then
        XCTAssertEqual(loadedState.messages.first?.content, "Hello world")
    }

    func test_applyAgentEvent_toolCallStarted_setsIsSearchingWeb() {
        // Given
        var loadedState = ChatViewModel.LoadedState()
        loadedState.isSearchingWeb = false
        let toolCall = ToolCall(
            id: "c1",
            type: "function",
            function: ToolCallFunction(name: "web_search", arguments: "{}")
        )
        let viewModel = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: MockAgentStreamUseCase(),
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        // When
        viewModel.applyAgentEvent(.toolCallStarted(toolCall), to: &loadedState, assistantMessageId: UUID())

        // Then
        XCTAssertTrue(loadedState.isSearchingWeb)
    }

    func test_applyAgentEvent_toolCallCompleted_clearsIsSearchingWeb() {
        // Given
        var loadedState = ChatViewModel.LoadedState()
        loadedState.isSearchingWeb = true
        let viewModel = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: MockAgentStreamUseCase(),
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        // When
        viewModel.applyAgentEvent(
            .toolCallCompleted(toolCallId: "c1", result: "results"),
            to: &loadedState,
            assistantMessageId: UUID()
        )

        // Then
        XCTAssertFalse(loadedState.isSearchingWeb)
    }

    func test_applyAgentEvent_agentError_setsErrorMessage() async throws {
        // Given
        let mockAgent = MockAgentStreamUseCase()
        mockAgent.error = APIError.networkError("Timeout")
        let modelWithFC = LLMModel(id: "gpt-4", capabilities: [.functionCalling])
        mockFetchModels.result = .success([modelWithFC])

        let sutWithAgent = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            agentStreamUseCase: mockAgent,
            webSearchUseCase: mockWebSearch,
            saveConversationUseCase: mockSaveConversation,
            exportConversationUseCase: mockExportConversation,
            branchConversationUseCase: mockBranchConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sutWithAgent.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sutWithAgent.send(.webSearchToggled)
        sutWithAgent.send(.inputChanged("search something"))

        // When
        sutWithAgent.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sutWithAgent.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertFalse(loadedState.isStreaming)
    }
}
