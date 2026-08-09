//
//  ConversationListViewModelTests+CloudSync.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests - Cloud Sync

@MainActor
extension ConversationListViewModelTests {
    func test_send_refreshTapped_synchronizesBeforeReloadingConversations() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        for _ in 0..<10 { await Task.yield() }
        let remoteConversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([remoteConversation])

        // When
        sut.send(.refreshTapped)

        // Then
        XCTAssertEqual(mockSyncConversations.executeCallCount, 2)
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations, [remoteConversation])
    }

    func test_cloudChangeNotification_synchronizesBeforeReloadingConversations() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([])
        sut.send(.viewAppeared)
        for _ in 0..<10 { await Task.yield() }
        let remoteConversation = Conversation(modelId: "gpt-4")
        mockLoadConversations.result = .success([remoteConversation])

        // When
        NotificationCenter.default.post(name: .conversationCloudDidChange, object: nil)
        try await Task.sleep(for: .milliseconds(600))

        // Then
        XCTAssertEqual(mockSyncConversations.executeCallCount, 2)
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversations, [remoteConversation])
    }

    func test_send_viewAppeared_withPendingDownload_retriesSynchronizationOnce() async throws {
        // Given
        mockLoadConversations.result = .success([])
        mockFetchModels.result = .success([])
        mockSyncConversations.results = [.pendingDownload, .synchronized]

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(1_100))

        // Then
        XCTAssertEqual(mockSyncConversations.executeCallCount, 2)
    }
}
