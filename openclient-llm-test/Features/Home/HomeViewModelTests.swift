//
//  HomeViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 07/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class HomeViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: HomeViewModel!
    private var mockGetSelectedModel: MockGetSelectedModelUseCase!
    private var mockLoadConversations: MockLoadConversationsUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        mockGetSelectedModel = MockGetSelectedModelUseCase()
        mockLoadConversations = MockLoadConversationsUseCase()
        sut = HomeViewModel(
            getSelectedModelUseCase: mockGetSelectedModel,
            loadConversationsUseCase: mockLoadConversations
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockGetSelectedModel = nil
        mockLoadConversations = nil
        try await super.tearDown()
    }

    // MARK: - newChatShortcutTriggered

    func test_send_newChatShortcutTriggered_setsConversationWithCorrectModelId() {
        mockGetSelectedModel.modelId = "gpt-4o"

        sut.send(.newChatShortcutTriggered)

        XCTAssertEqual(sut.pendingConversation?.modelId, "gpt-4o")
    }

    func test_send_newChatShortcutTriggered_whenNoModelSelected_usesEmptyString() {
        mockGetSelectedModel.modelId = ""

        sut.send(.newChatShortcutTriggered)

        XCTAssertEqual(sut.pendingConversation?.modelId, "")
    }

    // MARK: - pendingConversationConsumed

    func test_send_pendingConversationConsumed_clearsConversation() {
        mockGetSelectedModel.modelId = "gpt-4o"
        sut.send(.newChatShortcutTriggered)
        XCTAssertNotNil(sut.pendingConversation)

        sut.send(.pendingConversationConsumed)

        XCTAssertNil(sut.pendingConversation)
    }

    func test_send_pendingConversationConsumed_whenNilAlready_remainsNil() {
        sut.send(.pendingConversationConsumed)

        XCTAssertNil(sut.pendingConversation)
    }

    // MARK: - shortcutActionConsumed

    func test_send_shortcutActionConsumed_clearsPendingShortcutAction() {
        ShortcutManager.shared.pendingAction = .newChat
        XCTAssertNotNil(sut.pendingShortcutAction)

        sut.send(.shortcutActionConsumed)

        XCTAssertNil(sut.pendingShortcutAction)
        ShortcutManager.shared.pendingAction = nil
    }

    func test_pendingShortcutAction_reflectsShortcutManager() {
        ShortcutManager.shared.pendingAction = .search

        XCTAssertEqual(sut.pendingShortcutAction, .search)

        ShortcutManager.shared.pendingAction = nil
    }

    // MARK: - spotlightConversationRequested

    func test_send_spotlightConversationRequested_withMatchingId_setsPendingConversation() async throws {
        let id = UUID()
        let conversation = Conversation(id: id, modelId: "gpt-4o")
        mockLoadConversations.result = .success([conversation])

        sut.send(.spotlightConversationRequested(id))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(sut.pendingConversation?.id, id)
    }

    func test_send_spotlightConversationRequested_withNonMatchingId_doesNotSetConversation() async throws {
        let conversation = Conversation(id: UUID(), modelId: "gpt-4o")
        mockLoadConversations.result = .success([conversation])

        sut.send(.spotlightConversationRequested(UUID()))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertNil(sut.pendingConversation)
    }

    func test_send_spotlightConversationRequested_whenLoadFails_doesNotSetConversation() async throws {
        mockLoadConversations.result = .failure(URLError(.notConnectedToInternet))

        sut.send(.spotlightConversationRequested(UUID()))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertNil(sut.pendingConversation)
    }
}
