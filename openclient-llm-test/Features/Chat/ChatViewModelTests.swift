//
//  ChatViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ChatViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: ChatViewModel!
    var mockFetchModels: MockFetchModelsUseCase!
    var mockStreamMessage: MockStreamMessageUseCase!
    var mockSaveConversation: MockSaveConversationUseCase!
    var mockSettingsManager: MockSettingsManager!
    var mockConversationStarters: MockConversationStartersManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockFetchModels = MockFetchModelsUseCase()
        mockStreamMessage = MockStreamMessageUseCase()
        mockSaveConversation = MockSaveConversationUseCase()
        mockSettingsManager = MockSettingsManager()
        mockConversationStarters = MockConversationStartersManager()
        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockFetchModels = nil
        mockStreamMessage = nil
        mockSaveConversation = nil
        mockSettingsManager = nil
        mockConversationStarters = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_withModels_setsLoadedWithModels() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4"), LLMModel(id: "llama3")]
        mockFetchModels.result = .success(models)

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.availableModels.count, 2)
        XCTAssertEqual(loadedState.selectedModel?.id, "gpt-4")
        XCTAssertTrue(loadedState.messages.isEmpty)
        XCTAssertEqual(loadedState.conversationStarters.count, 4)
    }

    func test_send_viewAppeared_withError_setsErrorMessage() async throws {
        // Given
        mockFetchModels.result = .failure(APIError.serverUnreachable)

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertTrue(loadedState.availableModels.isEmpty)
    }

    // MARK: - Tests — inputChanged

    func test_send_inputChanged_updatesInputText() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.inputChanged("Hello"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.inputText, "Hello")
    }

    // MARK: - Tests — modelSelected

    func test_send_modelSelected_updatesSelectedModel() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4"), LLMModel(id: "llama3")]
        mockFetchModels.result = .success(models)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.modelSelected(models[1]))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedModel?.id, "llama3")
    }

    // MARK: - Tests — sendTapped

    func test_send_sendTapped_addsUserAndAssistantMessages() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hello"), .token(" there")]
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
        XCTAssertEqual(loadedState.messages.count, 2)
        XCTAssertEqual(loadedState.messages[0].role, .user)
        XCTAssertEqual(loadedState.messages[0].content, "Hi")
        XCTAssertEqual(loadedState.messages[1].role, .assistant)
        XCTAssertEqual(loadedState.messages[1].content, "Hello there")
        XCTAssertFalse(loadedState.isStreaming)
    }

    func test_send_sendTapped_clearsInputText() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Response")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))

        // When
        sut.send(.sendTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.inputText.isEmpty)
    }

    func test_send_sendTapped_withEmptyInput_doesNothing() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.messages.isEmpty)
    }

    func test_send_sendTapped_withNoModel_doesNothing() async throws {
        // Given
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))

        // When
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.messages.isEmpty)
    }

    func test_send_sendTapped_withStreamError_setsErrorMessage() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.error = APIError.serverUnreachable
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))

        // When
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertFalse(loadedState.isStreaming)
    }

    // MARK: - Tests — Model persistence

    func test_send_modelSelected_savesModelIdToSettings() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4"), LLMModel(id: "llama3")]
        mockFetchModels.result = .success(models)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.modelSelected(models[1]))

        // Then
        XCTAssertEqual(mockSettingsManager.selectedModelId, "llama3")
    }

    func test_send_viewAppeared_restoresSavedModel() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4"), LLMModel(id: "llama3")]
        mockFetchModels.result = .success(models)
        mockSettingsManager.selectedModelId = "llama3"

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedModel?.id, "llama3")
    }

    func test_send_viewAppeared_withInvalidSavedModel_fallsBackToFirst() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4"), LLMModel(id: "llama3")]
        mockFetchModels.result = .success(models)
        mockSettingsManager.selectedModelId = "deleted-model"

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedModel?.id, "gpt-4")
    }

    // MARK: - Tests — stopStreamingTapped

    func test_send_stopStreamingTapped_stopsStreaming() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hello"), .token(" "), .token("world")]
        mockStreamMessage.tokenDelay = .milliseconds(100)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hi"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(150))

        // When
        sut.send(.stopStreamingTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isStreaming)
    }

    // MARK: - Tests — suggestionTapped

    func test_send_suggestionTapped_sendsPromptAsMessage() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Response")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.suggestionTapped("Explain quantum computing"))
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.count, 2)
        XCTAssertEqual(loadedState.messages[0].role, .user)
        XCTAssertEqual(
            loadedState.messages[0].content,
            "Explain quantum computing"
        )
        XCTAssertEqual(loadedState.messages[1].role, .assistant)
    }
}
