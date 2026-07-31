//
//  SetWebSearchEnabledUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SetWebSearchEnabledUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: SetWebSearchEnabledUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = SetWebSearchEnabledUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — execute

    func test_execute_true_enablesWebSearch() {
        // When
        sut.execute(true)

        // Then
        XCTAssertTrue(mockSettingsManager.isWebSearchEnabled)
    }

    func test_execute_false_disablesWebSearch() {
        // Given
        mockSettingsManager.isWebSearchEnabled = true

        // When
        sut.execute(false)

        // Then
        XCTAssertFalse(mockSettingsManager.isWebSearchEnabled)
    }
}
