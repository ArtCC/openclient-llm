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
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "",
            memoryContext: "",
            conversationSystemPrompt: ""
        )
        XCTAssertTrue(result.contains("Respond in plain, natural language."))
        XCTAssertFalse(result.contains("background information"))
        XCTAssertFalse(result.contains("previous conversations"))
    }

    func test_buildEffectiveSystemPrompt_onlyProfile_returnsProfile() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "User is Alice.",
            memoryContext: "",
            conversationSystemPrompt: ""
        )
        XCTAssertTrue(result.contains("User is Alice."))
        XCTAssertTrue(result.contains("background information"))
        XCTAssertFalse(result.contains("previous conversations"))
    }

    func test_buildEffectiveSystemPrompt_onlyConversation_returnsConversation() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "",
            memoryContext: "",
            conversationSystemPrompt: "You are a coding assistant."
        )
        XCTAssertTrue(result.contains("You are a coding assistant."))
        XCTAssertTrue(result.contains("Respond in plain, natural language."))
        XCTAssertFalse(result.contains("background information"))
    }

    func test_buildEffectiveSystemPrompt_both_combineWithNewlines() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "User is Alice.",
            memoryContext: "",
            conversationSystemPrompt: "You are a coding assistant."
        )
        XCTAssertTrue(result.contains("User is Alice."))
        XCTAssertTrue(result.contains("You are a coding assistant."))
        XCTAssertTrue(result.contains("background information"))
    }

    func test_buildEffectiveSystemPrompt_trimsWhitespace() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "  User is Alice.  ",
            memoryContext: "",
            conversationSystemPrompt: "  Be concise.  "
        )
        XCTAssertTrue(result.contains("User is Alice."))
        XCTAssertTrue(result.contains("Be concise."))
    }

    func test_buildEffectiveSystemPrompt_withMemory_includesAllParts() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "User is Alice.",
            memoryContext: "## Memory\n- Prefers dark mode",
            conversationSystemPrompt: "You are a coding assistant."
        )
        XCTAssertTrue(result.contains("User is Alice."))
        XCTAssertTrue(result.contains("## Memory"))
        XCTAssertTrue(result.contains("- Prefers dark mode"))
        XCTAssertTrue(result.contains("You are a coding assistant."))
    }

    func test_buildEffectiveSystemPrompt_onlyMemory_returnsMemoryBlock() {
        let result = sut.buildEffectiveSystemPrompt(
            profileContext: "",
            memoryContext: "## Memory\n- Item 1",
            conversationSystemPrompt: ""
        )
        XCTAssertTrue(result.contains("## Memory"))
        XCTAssertTrue(result.contains("- Item 1"))
        XCTAssertTrue(result.contains("previous conversations"))
        XCTAssertFalse(result.contains("background information"))
    }
}
