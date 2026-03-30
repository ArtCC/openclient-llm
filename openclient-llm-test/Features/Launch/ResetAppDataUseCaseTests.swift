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

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = ResetAppDataUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil

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
}
