//
//  SaveServerConfigurationUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SaveServerConfigurationUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: SaveServerConfigurationUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = SaveServerConfigurationUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() {
        sut = nil
        mockSettingsManager = nil

        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_savesServerURL() {
        // When
        sut.execute(serverURL: "https://example.com", apiKey: "key")

        // Then
        XCTAssertEqual(mockSettingsManager.serverBaseURL, "https://example.com")
    }

    func test_execute_savesAPIKey() {
        // When
        sut.execute(serverURL: "https://example.com", apiKey: "test-key")

        // Then
        XCTAssertEqual(mockSettingsManager.apiKey, "test-key")
    }

    func test_execute_withEmptyValues_savesEmptyStrings() {
        // When
        sut.execute(serverURL: "", apiKey: "")

        // Then
        XCTAssertEqual(mockSettingsManager.serverBaseURL, "")
        XCTAssertEqual(mockSettingsManager.apiKey, "")
    }
}
