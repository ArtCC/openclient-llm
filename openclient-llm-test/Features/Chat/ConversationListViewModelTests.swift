//
//  ConversationListViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationListViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: ConversationListViewModel!
    private var mockLoadConversations: MockLoadConversationsUseCase!
    private var mockDeleteConversation: MockDeleteConversationUseCase!
    private var mockFetchModels: MockFetchModelsUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockLoadConversations = MockLoadConversationsUseCase()
        mockDeleteConversation = MockDeleteConversationUseCase()
        mockFetchModels = MockFetchModelsUseCase()
        mockSettingsManager = MockSettingsManager()
        sut = ConversationListViewModel(
            loadConversationsUseCase: mockLoadConversations,
            deleteConversationUseCase: mockDeleteConversation,
            fetchModelsUseCase: mockFetchModels,
            settingsManager: mockSettingsManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockLoadConversations = nil
        mockDeleteConversation = nil
        mockFetchModels = nil
        mockSettingsManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_loadsConversations() async throws {
        // Given
        let conversations = [
            Conversation(modelId: "gpt-4", messages: [ChatMessage(role: .user, content: "Hi")]),
            Conversation(modelId: "llama3")
        ]
        mockLoadConversations.result = .success(conversations)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.count, 2)
        XCTAssertEqual(loadedState.availableModels.count, 1)
        XCTAssertNil(loadedState.errorMessage)
    }

    func test_send_viewAppeared_withError_setsErrorMessage() async throws {
        // Given
        mockLoadConversations.result = .failure(NSError(domain: "test", code: 1))
        mockFetchModels.result = .success([])

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.conversations.isEmpty)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    func test_send_viewAppeared_withModelsError_stillLoadsConversations() async throws {
        // Given
        let conversations = [Conversation(modelId: "gpt-4")]
        mockLoadConversations.result = .success(conversations)
        mockFetchModels.result = .failure(NSError(domain: "test", code: 1))

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.count, 1)
        XCTAssertTrue(loadedState.availableModels.isEmpty)
    }

    // MARK: - Tests — newConversationTapped

    func test_send_newConversationTapped_callsOnConversationSelected() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        var selectedConversation: Conversation?
        sut.onConversationSelected = { selectedConversation = $0 }

        // When
        sut.send(.newConversationTapped)

        // Then
        XCTAssertNotNil(selectedConversation)
        XCTAssertEqual(selectedConversation?.modelId, "gpt-4")
    }

    func test_send_newConversationTapped_usesSelectedModelFromSettings() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([LLMModel(id: "gpt-4"), LLMModel(id: "llama3")])
        mockSettingsManager.selectedModelId = "llama3"
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        var selectedConversation: Conversation?
        sut.onConversationSelected = { selectedConversation = $0 }

        // When
        sut.send(.newConversationTapped)

        // Then
        XCTAssertEqual(selectedConversation?.modelId, "llama3")
    }

    func test_send_newConversationTapped_noModels_doesNothing() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        var callbackCalled = false
        sut.onConversationSelected = { _ in callbackCalled = true }

        // When
        sut.send(.newConversationTapped)

        // Then
        XCTAssertFalse(callbackCalled)
    }

    // MARK: - Tests — conversationTapped

    func test_send_conversationTapped_selectsConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        var selectedConversation: Conversation?
        sut.onConversationSelected = { selectedConversation = $0 }

        // When
        sut.send(.conversationTapped(conversation))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedConversation, conversation)
        XCTAssertEqual(selectedConversation, conversation)
    }

    // MARK: - Tests — deleteConversation

    func test_send_deleteConversation_removesFromList() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.deleteConversation(conversation.id))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.conversations.isEmpty)
        XCTAssertEqual(mockDeleteConversation.deletedIds, [conversation.id])
    }

    func test_send_deleteConversation_clearsSelectionIfSelected() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.conversationTapped(conversation))

        var deselectedCalled = false
        sut.onConversationSelected = { conversation in
            if conversation == nil { deselectedCalled = true }
        }

        // When
        sut.send(.deleteConversation(conversation.id))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.selectedConversation)
        XCTAssertTrue(deselectedCalled)
    }

    func test_send_deleteConversation_withError_setsErrorMessage() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        mockDeleteConversation.error = NSError(domain: "test", code: 1)

        // When
        sut.send(.deleteConversation(conversation.id))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        // Conversation should still be in the list since delete failed
        XCTAssertEqual(loadedState.conversations.count, 1)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    // MARK: - Tests — refresh

    func test_refresh_reloadsConversations() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let newConversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([newConversation])

        // When
        sut.refresh()

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.count, 1)
    }
}
