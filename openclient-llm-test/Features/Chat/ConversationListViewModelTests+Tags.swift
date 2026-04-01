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
        let conv1 = Conversation(modelId: "gpt-4", tags: ["swift", "ai"])
        let conv2 = Conversation(modelId: "gpt-4", tags: ["ai", "coding"])
        mockLoadConversations.result = .success([conv1, conv2])
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
        let conv1 = Conversation(title: "Swift Chat", modelId: "gpt-4", tags: ["swift"])
        let conv2 = Conversation(title: "AI Chat", modelId: "gpt-4", tags: ["ai"])
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
        let conv1 = Conversation(title: "Swift Chat", modelId: "gpt-4", tags: ["swift"])
        let conv2 = Conversation(title: "AI Chat", modelId: "gpt-4", tags: ["ai"])
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
}
