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
    private var mockPinConversation: MockPinConversationUseCase!
    private var mockUpdateTags: MockUpdateConversationTagsUseCase!
    private var mockFetchModels: MockFetchModelsUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockLoadConversations = MockLoadConversationsUseCase()
        mockDeleteConversation = MockDeleteConversationUseCase()
        mockPinConversation = MockPinConversationUseCase()
        mockUpdateTags = MockUpdateConversationTagsUseCase()
        mockFetchModels = MockFetchModelsUseCase()
        mockSettingsManager = MockSettingsManager()
        sut = ConversationListViewModel(
            loadConversationsUseCase: mockLoadConversations,
            deleteConversationUseCase: mockDeleteConversation,
            pinConversationUseCase: mockPinConversation,
            updateConversationTagsUseCase: mockUpdateTags,
            fetchModelsUseCase: mockFetchModels,
            settingsManager: mockSettingsManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockLoadConversations = nil
        mockDeleteConversation = nil
        mockPinConversation = nil
        mockUpdateTags = nil
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

    func test_send_newConversationTapped_noModels_createsConversationWithEmptyModelId() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        var selectedConversation: Conversation?
        sut.onConversationSelected = { selectedConversation = $0 }

        // When
        sut.send(.newConversationTapped)

        // Then
        XCTAssertNotNil(selectedConversation)
        XCTAssertEqual(selectedConversation?.modelId, "")
        XCTAssertTrue(selectedConversation?.messages.isEmpty ?? false)
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

    // MARK: - Tests — searchChanged

    func test_send_searchChanged_filtersByTitle() async throws {
        // Given
        let conversations = [
            Conversation(title: "Swift coding", modelId: "gpt-4"),
            Conversation(title: "Python tips", modelId: "gpt-4"),
            Conversation(title: "SwiftUI views", modelId: "llama3")
        ]
        mockLoadConversations.result = .success(conversations)
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.searchChanged("Swift"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.filteredConversations.count, 2)
        XCTAssertEqual(loadedState.searchQuery, "Swift")
    }

    func test_send_searchChanged_filtersByMessageContent() async throws {
        // Given
        let conversations = [
            Conversation(
                title: "Chat 1",
                modelId: "gpt-4",
                messages: [ChatMessage(role: .user, content: "Tell me about quantum physics")]
            ),
            Conversation(
                title: "Chat 2",
                modelId: "gpt-4",
                messages: [ChatMessage(role: .user, content: "Write a poem")]
            )
        ]
        mockLoadConversations.result = .success(conversations)
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.searchChanged("quantum"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.filteredConversations.count, 1)
        XCTAssertEqual(loadedState.filteredConversations.first?.title, "Chat 1")
    }

    func test_send_searchChanged_withEmptyQuery_showsAll() async throws {
        // Given
        let conversations = [
            Conversation(title: "Chat 1", modelId: "gpt-4"),
            Conversation(title: "Chat 2", modelId: "gpt-4")
        ]
        mockLoadConversations.result = .success(conversations)
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.searchChanged("Chat 1"))

        // When
        sut.send(.searchChanged(""))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.filteredConversations.count, 2)
    }

    func test_send_searchChanged_noMatch_returnsEmpty() async throws {
        // Given
        let conversations = [
            Conversation(title: "Chat 1", modelId: "gpt-4"),
            Conversation(title: "Chat 2", modelId: "gpt-4")
        ]
        mockLoadConversations.result = .success(conversations)
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.searchChanged("nonexistent"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.filteredConversations.isEmpty)
    }

    // MARK: - Tests — pinToggled

    func test_send_pinToggled_pinsConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.pinToggled(conversation.id))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(mockPinConversation.executedId, conversation.id)
        XCTAssertEqual(mockPinConversation.executedIsPinned, true)
        XCTAssertTrue(loadedState.conversations.first?.isPinned ?? false)
    }

    func test_send_pinToggled_unpinsAlreadyPinnedConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4", isPinned: true)
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.pinToggled(conversation.id))

        // Then
        XCTAssertEqual(mockPinConversation.executedIsPinned, false)

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.conversations.first?.isPinned ?? true)
    }

    func test_send_pinToggled_pinnedConversationsAppearInPinnedSection() async throws {
        // Given
        let pinned = Conversation(title: "Pinned", modelId: "gpt-4", isPinned: true)
        let unpinned = Conversation(title: "Unpinned", modelId: "gpt-4")
        mockLoadConversations.result = .success([pinned, unpinned])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let pinnedSection = loadedState.groupedConversations.first(where: { $0.period == .pinned })
        XCTAssertNotNil(pinnedSection)
        XCTAssertEqual(pinnedSection?.conversations.count, 1)
        XCTAssertEqual(pinnedSection?.conversations.first?.title, "Pinned")
    }

    // MARK: - Tests — tagsUpdated

    func test_send_tagsUpdated_savesTagsForConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.tagsUpdated(conversation.id, ["swift", "ai"]))

        // Then
        XCTAssertEqual(mockUpdateTags.executedId, conversation.id)
        XCTAssertEqual(mockUpdateTags.executedTags, ["swift", "ai"])

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.first?.tags, ["swift", "ai"])
    }

    func test_send_tagsUpdated_allTagsComputedCorrectly() async throws {
        // Given
        let c1 = Conversation(modelId: "gpt-4", tags: ["swift", "ai"])
        let c2 = Conversation(modelId: "gpt-4", tags: ["ai", "coding"])
        mockLoadConversations.result = .success([c1, c2])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        // allTags should be sorted and deduplicated
        XCTAssertEqual(loadedState.allTags, ["ai", "coding", "swift"])
    }

    // MARK: - Tests — tagFilterChanged

    func test_send_tagFilterChanged_filtersConversationsByTag() async throws {
        // Given
        let c1 = Conversation(title: "Swift Chat", modelId: "gpt-4", tags: ["swift"])
        let c2 = Conversation(title: "AI Chat", modelId: "gpt-4", tags: ["ai"])
        mockLoadConversations.result = .success([c1, c2])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.tagFilterChanged("swift"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.filteredConversations.count, 1)
        XCTAssertEqual(loadedState.filteredConversations.first?.title, "Swift Chat")
        XCTAssertEqual(loadedState.activeTagFilter, "swift")
    }

    func test_send_tagFilterChanged_nil_showsAll() async throws {
        // Given
        let c1 = Conversation(title: "Swift Chat", modelId: "gpt-4", tags: ["swift"])
        let c2 = Conversation(title: "AI Chat", modelId: "gpt-4", tags: ["ai"])
        mockLoadConversations.result = .success([c1, c2])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.tagFilterChanged("swift"))

        // When
        sut.send(.tagFilterChanged(nil))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.filteredConversations.count, 2)
        XCTAssertNil(loadedState.activeTagFilter)
    }
}
