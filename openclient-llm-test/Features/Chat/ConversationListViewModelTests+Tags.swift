//
//  ConversationListViewModelTests+Tags.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Tags

@MainActor
extension ConversationListViewModelTests {
    func test_send_tagsUpdated_savesTagsForConversation() async throws {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([conversation])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        let tags = [
            ConversationTag(name: "swift", color: .orange),
            ConversationTag(name: "ai", color: .blue)
        ]

        // When
        sut.send(.tagsUpdated(conversation.id, tags))
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.conversations.first?.tags == tags
        }

        // Then
        XCTAssertEqual(mockUpdateTags.executedId, conversation.id)
        XCTAssertEqual(mockUpdateTags.executedTags, tags)

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations.first?.tags, tags)
    }

    func test_send_tagsUpdated_allTagsComputedCorrectly() async throws {
        // Given
        let conv1 = Conversation(modelId: "gpt-4", tags: [
            ConversationTag(name: "swift", color: .orange),
            ConversationTag(name: "ai", color: .blue)
        ])
        let conv2 = Conversation(modelId: "gpt-4", tags: [
            ConversationTag(name: "ai", color: .blue),
            ConversationTag(name: "coding", color: .green)
        ])
        mockLoadConversations.result = .success([conv1, conv2])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        // allTags should be sorted alphabetically (case-insensitive) and deduplicated
        XCTAssertEqual(loadedState.allTags.map(\.name), ["ai", "coding", "swift"])
    }

    func test_allTags_sortedCaseInsensitively() async throws {
        // Given — mixed-case tags to verify case-insensitive alphabetical ordering
        let conv1 = Conversation(modelId: "gpt-4", tags: [
            ConversationTag(name: "Swift", color: .orange),
            ConversationTag(name: "AI", color: .blue)
        ])
        let conv2 = Conversation(modelId: "gpt-4", tags: [
            ConversationTag(name: "coding", color: .green),
            ConversationTag(name: "Backend", color: .purple)
        ])
        mockLoadConversations.result = .success([conv1, conv2])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        // "AI" < "Backend" < "coding" < "Swift" when sorted case-insensitively
        let expectedOrder = ["AI", "Backend", "coding", "Swift"]
        XCTAssertEqual(loadedState.allTags.map(\.name), expectedOrder)
        // Verify the first tag is not affected by case — "All" chip is rendered before this list in the view
        XCTAssertFalse(loadedState.allTags.isEmpty)
    }

    // MARK: - Tests — tagFilterChanged

    func test_send_tagFilterChanged_filtersConversationsByTag() async throws {
        // Given
        let conv1 = Conversation(
            title: "Swift Chat",
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .orange)]
        )
        let conv2 = Conversation(
            title: "AI Chat",
            modelId: "gpt-4",
            tags: [ConversationTag(name: "ai", color: .blue)]
        )
        mockLoadConversations.result = .success([conv1, conv2])
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
        let conv1 = Conversation(
            title: "Swift Chat",
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .orange)]
        )
        let conv2 = Conversation(
            title: "AI Chat",
            modelId: "gpt-4",
            tags: [ConversationTag(name: "ai", color: .blue)]
        )
        mockLoadConversations.result = .success([conv1, conv2])
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

    func test_send_tagsUpdated_removingLastActiveTag_clearsFilter() async throws {
        // Given
        let conv1 = Conversation(
            title: "Swift Chat",
            modelId: "gpt-4",
            tags: [ConversationTag(name: "swift", color: .orange)]
        )
        let conv2 = Conversation(
            title: "AI Chat",
            modelId: "gpt-4",
            tags: [ConversationTag(name: "ai", color: .blue)]
        )
        mockLoadConversations.result = .success([conv1, conv2])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.tagFilterChanged("swift"))

        // When
        sut.send(.tagsUpdated(conv1.id, []))
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.activeTagFilter == nil
                && loadedState.conversations.first(where: { $0.id == conv1.id })?.tags.isEmpty == true
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.activeTagFilter)
        XCTAssertEqual(loadedState.filteredConversations.count, 2)
    }
}
