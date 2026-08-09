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
    private var mockRemoteConfigManager: MockRemoteConfigManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockUseCase = MockCheckOnboardingUseCase()
        mockResetAppData = MockResetAppDataUseCase()
        mockAttachmentMigration = MockAttachmentMigrationUseCase()
        mockRemoteConfigManager = MockRemoteConfigManager()
        sut = LaunchViewModel(
            checkOnboardingUseCase: mockUseCase,
            resetAppDataUseCase: mockResetAppData,
            attachmentMigrationUseCase: mockAttachmentMigration,
            remoteConfigManager: mockRemoteConfigManager,
            currentVersion: "1.6.10",
            launchDelay: .zero
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockUseCase = nil
        mockResetAppData = nil
        mockAttachmentMigration = nil
        mockRemoteConfigManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    func test_send_viewAppeared_onboardingNotCompleted_setsOnboardingState() async {
        // Given
        mockUseCase.result = false

        // When
        sut.send(.viewAppeared)
        await waitForLaunch()

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

    func test_send_viewAppeared_onboardingCompleted_setsHomeState() async {
        // Given
        mockUseCase.result = true

        // When
        sut.send(.viewAppeared)
        await waitForLaunch()

        // Then
        XCTAssertEqual(sut.state, .home)
    }

    func test_send_viewAppeared_withLaunchDelay_keepsLoadingStateUntilDelayFinishes() {
        // Given
        mockUseCase.result = true
        sut = LaunchViewModel(
            checkOnboardingUseCase: mockUseCase,
            resetAppDataUseCase: mockResetAppData,
            attachmentMigrationUseCase: mockAttachmentMigration,
            remoteConfigManager: mockRemoteConfigManager,
            currentVersion: "1.6.10",
            launchDelay: .milliseconds(500)
        )

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(sut.state, .loading)
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
            attachmentMigrationUseCase: mockAttachmentMigration,
            remoteConfigManager: mockRemoteConfigManager,
            currentVersion: "1.6.10",
            launchDelay: .zero
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

    func test_send_viewAppeared_forceUpdateEnabledForNewerVersion_setsForceUpdateState() async {
        // Given
        mockUseCase.result = true
        mockRemoteConfigManager.result = .success(.stub(isForceUpdate: true, latestVersion: "2.0.0"))

        // When
        sut.send(.viewAppeared)
        await waitForLaunch()

        // Then
        guard case .forceUpdate(let update) = sut.state else {
            return XCTFail("Expected force update state")
        }
        XCTAssertEqual(update.latestVersion, "2.0.0")
    }

    func test_send_viewAppeared_forceUpdateDisabled_setsHomeState() async {
        // Given
        mockUseCase.result = true
        mockRemoteConfigManager.result = .success(.stub(isForceUpdate: false, latestVersion: "2.0.0"))

        // When
        sut.send(.viewAppeared)
        await waitForLaunch()

        // Then
        XCTAssertEqual(sut.state, .home)
    }

    func test_send_viewAppeared_currentVersionIsNewer_setsHomeState() async {
        // Given
        mockUseCase.result = true
        mockRemoteConfigManager.result = .success(.stub(isForceUpdate: true, latestVersion: "1.5.0"))

        // When
        sut.send(.viewAppeared)
        await waitForLaunch()

        // Then
        XCTAssertEqual(sut.state, .home)
    }

    func test_send_viewAppeared_maintenanceEnabled_setsMaintenanceState() async {
        // Given
        mockUseCase.result = true
        mockRemoteConfigManager.result = .success(.stub(isMaintenanceEnabled: true))

        // When
        sut.send(.viewAppeared)
        await waitForLaunch()

        // Then
        XCTAssertEqual(sut.state, .maintenance)
    }

    func test_send_viewAppeared_maintenanceAndForceUpdateEnabled_setsMaintenanceState() async {
        // Given
        mockUseCase.result = true
        mockRemoteConfigManager.result = .success(
            .stub(isMaintenanceEnabled: true, isForceUpdate: true, latestVersion: "2.0.0")
        )

        // When
        sut.send(.viewAppeared)
        await waitForLaunch()

        // Then
        XCTAssertEqual(sut.state, .maintenance)
    }
}

// MARK: - Private

private extension LaunchViewModelTests {
    func waitForLaunch() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }
}
