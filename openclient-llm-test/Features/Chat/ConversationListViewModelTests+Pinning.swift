//
//  ConversationListViewModelTests+Pinning.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Pinning

@MainActor
extension ConversationListViewModelTests {
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
}
