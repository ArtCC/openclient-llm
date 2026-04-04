//
//  ResetAppDataUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ResetAppDataUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: ResetAppDataUseCase!
    private var mockSettingsManager: MockSettingsManager!
    private var mockConversationRepository: MockConversationRepository!
    private var mockUserProfileManager: MockUserProfileManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsManager = MockSettingsManager()
        mockConversationRepository = MockConversationRepository()
        mockUserProfileManager = MockUserProfileManager()
        sut = ResetAppDataUseCase(
            settingsManager: mockSettingsManager,
            conversationRepository: mockConversationRepository,
            userProfileManager: mockUserProfileManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil
        mockConversationRepository = nil
        mockUserProfileManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_callsDeleteAll() {
        // Given
        mockSettingsManager.serverBaseURL = "https://example.com"
        mockSettingsManager.apiKey = "sk-test"

        // When
        sut.execute()

        // Then
        XCTAssertTrue(mockSettingsManager.deleteAllCalled)
    }

    func test_execute_deletesAllConversations() {
        // Given
        let conversation = Conversation(modelId: "gpt-4")
        mockConversationRepository.conversations = [conversation]

        // When
        sut.execute()

        // Then
        XCTAssertTrue(mockConversationRepository.conversations.isEmpty)
    }

    func test_execute_deletesLocalProfile() {
        // Given
        mockUserProfileManager.localProfile = UserProfile(name: "Test", profileDescription: "", extraInfo: "")

        // When
        sut.execute()

        // Then
        XCTAssertTrue(mockUserProfileManager.localProfile.isEmpty)
    }
}
