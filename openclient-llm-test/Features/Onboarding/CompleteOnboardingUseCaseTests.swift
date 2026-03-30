//
//  CompleteOnboardingUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CompleteOnboardingUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: CompleteOnboardingUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = CompleteOnboardingUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_setsOnboardingCompleted() {
        // Given
        XCTAssertFalse(mockSettingsManager.isOnboardingCompleted)

        // When
        sut.execute()

        // Then
        XCTAssertTrue(mockSettingsManager.isOnboardingCompleted)
    }
}
