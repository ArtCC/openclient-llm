//
//  ChatViewModelTests+UserProfile.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ChatViewModelUserProfileTests: XCTestCase {
    // MARK: - Properties

    private var sut: ChatViewModel!
    private var mockFetchModels: MockFetchModelsUseCase!
    private var mockStreamMessage: MockStreamMessageUseCase!
    private var mockSaveConversation: MockSaveConversationUseCase!
    private var mockGetChatPreferences: MockGetChatPreferencesUseCase!
    private var mockGetUserProfileContext: MockGetUserProfileContextUseCase!
    private var mockGetConversationStarters: MockGetConversationStartersUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockFetchModels = MockFetchModelsUseCase()
        mockStreamMessage = MockStreamMessageUseCase()
        mockSaveConversation = MockSaveConversationUseCase()
        mockGetChatPreferences = MockGetChatPreferencesUseCase()
        mockGetUserProfileContext = MockGetUserProfileContextUseCase()
        mockGetConversationStarters = MockGetConversationStartersUseCase()
        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            getChatPreferencesUseCase: mockGetChatPreferences,
            getUserProfileContextUseCase: mockGetUserProfileContext,
            getConversationStartersUseCase: mockGetConversationStarters
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockFetchModels = nil
        mockStreamMessage = nil
        mockSaveConversation = nil
        mockGetChatPreferences = nil
        mockGetUserProfileContext = nil
        mockGetConversationStarters = nil
        try await super.tearDown()
    }

    // MARK: - Tests — buildEffectiveSystemPrompt

    func test_buildEffectiveSystemPrompt_bothEmpty_returnsEmpty() {
        let result = sut.buildEffectiveSystemPrompt(profileContext: "", conversationSystemPrompt: "")
        XCTAssertEqual(result, "")
    }

    func test_buildEffectiveSystemPrompt_onlyProfile_returnsProfile() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "User is Alice.",
            conversationSystemPrompt: ""
        )
        XCTAssertEqual(result, "User is Alice.")
    }

    func test_buildEffectiveSystemPrompt_onlyConversation_returnsConversation() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "",
            conversationSystemPrompt: "You are a coding assistant."
        )
        XCTAssertEqual(result, "You are a coding assistant.")
    }

    func test_buildEffectiveSystemPrompt_both_combineWithNewlines() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "User is Alice.",
            conversationSystemPrompt: "You are a coding assistant."
        )
        XCTAssertEqual(result, "User is Alice.\n\nYou are a coding assistant.")
    }

    func test_buildEffectiveSystemPrompt_trimsWhitespace() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "  User is Alice.  ",
            conversationSystemPrompt: "  Be concise.  "
        )
        XCTAssertTrue(result.contains("User is Alice."))
        XCTAssertTrue(result.contains("Be concise."))
    }
}
