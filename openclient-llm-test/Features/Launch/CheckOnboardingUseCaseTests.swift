//
//  CheckOnboardingUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//

import XCTest
@testable import openclient_llm

final class CheckOnboardingUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: CheckOnboardingUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = CheckOnboardingUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() {
        sut = nil
        mockSettingsManager = nil

        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_onboardingNotCompleted_returnsFalse() {
        // Given
        mockSettingsManager.isOnboardingCompleted = false

        // When
        let result = sut.execute()

        // Then
        XCTAssertFalse(result)
    }

    func test_execute_onboardingCompleted_returnsTrue() {
        // Given
        mockSettingsManager.isOnboardingCompleted = true

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result)
    }
}
