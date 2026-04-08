//
//  ChatViewModelTests+WebSearch.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Web Search

@MainActor
extension ChatViewModelTests {
    func test_send_webSearchToggled_flipsIsWebSearchEnabled() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        guard case .loaded(let before) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(before.isWebSearchEnabled)

        // When
        sut.send(.webSearchToggled)

        // Then
        guard case .loaded(let after) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(after.isWebSearchEnabled)
    }

    func test_send_webSearchToggled_twice_returnsFalse() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.webSearchToggled)
        sut.send(.webSearchToggled)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isWebSearchEnabled)
    }

    func test_send_sendTapped_withWebSearchEnabled_noCapabilities_usesRegularStreaming() async throws {
        // Given — default model has no capabilities, so web search enabled falls through to regular streaming
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Regular answer.")]

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.webSearchToggled)
        sut.send(.inputChanged("Tell me about Swift 6"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(300))

        // Then — web search use case NOT called (model has no capabilities)
        XCTAssertEqual(mockWebSearch.executeCallCount, 0)

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertEqual(assistantMessage?.role, .assistant)
        XCTAssertEqual(assistantMessage?.content, "Regular answer.")
    }

    func test_send_sendTapped_withWebSearchDisabled_doesNotCallWebSearch() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hello")]

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Web search is disabled by default
        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        XCTAssertEqual(mockWebSearch.executeCallCount, 0)

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertNil(assistantMessage?.webSearchResults)
    }

    func test_send_sendTapped_withWebSearchEnabled_functionCallingModel_usesAgent() async throws {
        // Given — model WITH functionCalling → agent mode when web search ON
        let mockAgent = MockAgentStreamUseCase()
        mockAgent.events = [.token("Agent answer.")]
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
            getChatPreferencesUseCase: mockGetChatPreferences,
            getConversationStartersUseCase: mockGetConversationStarters
        )

        sutWithAgent.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sutWithAgent.send(.webSearchToggled)
        sutWithAgent.send(.inputChanged("What is the weather?"))
        sutWithAgent.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(300))

        // Then — agent use case used, webSearch use case NOT called directly
        guard case .loaded(let loadedState) = sutWithAgent.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertEqual(assistantMessage?.content, "Agent answer.")
        XCTAssertEqual(mockWebSearch.executeCallCount, 0)
        XCTAssertFalse(loadedState.isStreaming)
    }
}
