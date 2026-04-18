//
//  LaunchViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class LaunchViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: LaunchViewModel!
    private var mockUseCase: MockCheckOnboardingUseCase!
    private var mockResetAppData: MockResetAppDataUseCase!
    private var mockAttachmentMigration: MockAttachmentMigrationUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockUseCase = MockCheckOnboardingUseCase()
        mockResetAppData = MockResetAppDataUseCase()
        mockAttachmentMigration = MockAttachmentMigrationUseCase()
        sut = LaunchViewModel(
            checkOnboardingUseCase: mockUseCase,
            resetAppDataUseCase: mockResetAppData,
            attachmentMigrationUseCase: mockAttachmentMigration
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockUseCase = nil
        mockResetAppData = nil
        mockAttachmentMigration = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    func test_send_viewAppeared_onboardingNotCompleted_setsOnboardingState() {
        // Given
        mockUseCase.result = false

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(sut.state, .onboarding)
    }

    func test_send_viewAppeared_onboardingNotCompleted_resetsAppData() {
        // Given
        mockUseCase.result = false

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertTrue(mockResetAppData.executeCalled)
    }

    func test_send_viewAppeared_onboardingCompleted_setsHomeState() {
        // Given
        mockUseCase.result = true

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(sut.state, .home)
    }

    func test_send_viewAppeared_onboardingCompleted_doesNotResetAppData() {
        // Given
        mockUseCase.result = true

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertFalse(mockResetAppData.executeCalled)
    }

    func test_send_onboardingCompleted_setsHomeState() {
        // Given
        sut = LaunchViewModel(
            state: .onboarding,
            checkOnboardingUseCase: mockUseCase,
            resetAppDataUseCase: mockResetAppData,
            attachmentMigrationUseCase: mockAttachmentMigration
        )

        // When
        sut.send(.onboardingCompleted)

        // Then
        XCTAssertEqual(sut.state, .home)
    }

    func test_send_viewAppeared_triggersAttachmentMigration() {
        // Given
        mockUseCase.result = true

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(mockAttachmentMigration.executeCallCount, 1)
    }
}
