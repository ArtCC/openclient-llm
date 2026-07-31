//
//  GetChatPreferencesUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class GetChatPreferencesUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: GetChatPreferencesUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = GetChatPreferencesUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — getSelectedModelId

    func test_getSelectedModelId_delegatesToSettingsManager() {
        mockSettingsManager.selectedModelId = "gpt-4"
        XCTAssertEqual(sut.getSelectedModelId(), "gpt-4")
    }

    func test_getSelectedModelId_nil_delegatesToSettingsManager() {
        mockSettingsManager.selectedModelId = nil
        XCTAssertNil(sut.getSelectedModelId())
    }

    // MARK: - Tests — getShowTokenUsage

    func test_getShowTokenUsage_true_delegatesToSettingsManager() {
        mockSettingsManager.showTokenUsage = true
        XCTAssertTrue(sut.getShowTokenUsage())
    }

    func test_getShowTokenUsage_false_delegatesToSettingsManager() {
        mockSettingsManager.showTokenUsage = false
        XCTAssertFalse(sut.getShowTokenUsage())
    }

    // MARK: - Tests — getIsWebSearchEnabled

    func test_getIsWebSearchEnabled_true_delegatesToSettingsManager() {
        mockSettingsManager.isWebSearchEnabled = true
        XCTAssertTrue(sut.getIsWebSearchEnabled())
    }

    func test_getIsWebSearchEnabled_false_delegatesToSettingsManager() {
        mockSettingsManager.isWebSearchEnabled = false
        XCTAssertFalse(sut.getIsWebSearchEnabled())
    }

    // MARK: - Tests — getWebSearchToolName

    func test_getWebSearchToolName_delegatesToSettingsManager() {
        mockSettingsManager.webSearchToolName = "brave-search"
        XCTAssertEqual(sut.getWebSearchToolName(), "brave-search")
    }

    // MARK: - Tests — getSelectedTTSVoice

    func test_getSelectedTTSVoice_delegatesToSettingsManager() {
        mockSettingsManager.ttsVoices = ["tts-1": "nova"]
        XCTAssertEqual(sut.getSelectedTTSVoice(forModelId: "tts-1"), "nova")
    }
}
