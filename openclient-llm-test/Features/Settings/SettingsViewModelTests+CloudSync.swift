//
//  SettingsViewModelTests+CloudSync.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension SettingsViewModelTests {
    // MARK: - Toggle

    func test_send_cloudSyncToggled_enablesSync() async {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockEnableCloudSync.startCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
        XCTAssertTrue(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertEqual(mockEnableCloudSync.startCallCount, 1)
    }

    func test_send_cloudSyncToggled_false_cancelsCoordinatorPreflightAndDisablesImmediately() async {
        // Given
        let gate = TestAsyncGate()
        mockEnableCloudSync.executeHandler = {
            await gate.wait()
            return .ready
        }
        sut.send(.viewAppeared)
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockEnableCloudSync.executeCallCount == 1 }

        // When
        sut.send(.cloudSyncToggled(false))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isCloudSyncEnabled)
        XCTAssertFalse(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertNil(sut.cloudEnableTask)
        XCTAssertNil(sut.synchronizationTask)
        XCTAssertEqual(mockEnableCloudSync.stopCallCount, 1)
        XCTAssertEqual(cloudSyncRuntimeStore.status, .disabled)
        await gate.open()
        await waitUntil { self.mockEnableCloudSync.executeCancellationCallCount == 1 }
    }

    func test_send_cloudSyncToggled_profileDownloadPending_keepsIntentEnabledAndShowsPending() async {
        // Given
        mockEnableCloudSync.result = .failure(CloudSyncError.requiredDownloadPending)
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockEnableCloudSync.executeCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
        XCTAssertTrue(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertNil(mockUserProfileManager.resolvedKeepLocal)
        XCTAssertEqual(mockSynchronizeAppData.executeCallCount, 0)
        XCTAssertEqual(mockEnableCloudSync.startCallCount, 1)
    }

    func test_send_cloudSyncToggled_true_enablesDirectly_whenBothMatch() async {
        // Given
        let sameProfile = UserProfile(name: "Same", profileDescription: "Desc", extraInfo: "Info")
        mockUserProfileManager.localProfile = sameProfile
        mockUserProfileManager.cloudProfile = sameProfile
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockSettingsManager.isCloudSyncEnabled }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertFalse(loadedState.showCloudSyncConflictAlert)
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
    }

    func test_send_cloudSyncToggled_unassociated_requiresConfirmationBeforeExplicitApproval() async {
        // Given
        mockCloudAccountAssociation.associationState = .unassociated
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))

        // Then
        guard case .loaded(let reviewState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertTrue(reviewState.showCloudAccountReviewAlert)
        XCTAssertFalse(reviewState.isCloudSyncEnabled)
        XCTAssertFalse(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertEqual(mockEnableCloudSync.approveCurrentAccountCallCount, 0)

        // When
        sut.send(.cloudAccountReviewConfirmed)

        // Then
        await waitUntil { self.mockEnableCloudSync.approveCurrentAccountCallCount == 1 }
        XCTAssertTrue(mockSettingsManager.isCloudSyncEnabled)
    }

    func test_send_cloudSyncToggled_disableDuringPreflight_doesNotLateReenable() async {
        // Given
        let gate = TestAsyncGate()
        mockEnableCloudSync.executeHandler = {
            await gate.wait()
            return .ready
        }
        sut.send(.viewAppeared)
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockEnableCloudSync.executeCallCount == 1 }

        // When
        sut.send(.cloudSyncToggled(false))
        await gate.open()
        await waitUntil { self.mockEnableCloudSync.executeCancellationCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertFalse(loadedState.isCloudSyncEnabled)
        XCTAssertFalse(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertEqual(cloudSyncRuntimeStore.status, .disabled)
        XCTAssertEqual(mockSynchronizeAppData.executeCallCount, 0)
    }

    // MARK: - Manual Sync

    func test_send_syncNowTapped_partialFailure_retainsCategoryResult() async {
        // Given
        mockSettingsManager.isCloudSyncEnabled = true
        mockSynchronizeAppData.result = AppSynchronizationResult(outcomes: [
            .conversations: .synchronized,
            .profile: .synchronized,
            .memory: .failed,
            .promptTemplates: .pendingDownload
        ])
        sut.send(.viewAppeared)
        let generation = cloudSyncRuntimeStore.begin(.idle(lastSuccessfulSyncAt: nil))
        cloudSyncRuntimeStore.completePreflight(generation: generation)

        // When
        sut.send(.syncNowTapped)
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.synchronizationResult == self.mockSynchronizeAppData.result
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.synchronizationResult?.categories(with: .failed), [.memory])
        XCTAssertEqual(loadedState.synchronizationResult?.categories(with: .pendingDownload), [.promptTemplates])
        XCTAssertFalse(loadedState.synchronizationResult?.isSuccessful ?? true)
    }

    func test_send_cloudAvailabilityRefresh_enabled_routesThroughCoordinatorPreflight() {
        // Given
        mockSettingsManager.isCloudSyncEnabled = true
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudAvailabilityRefresh)

        // Then
        XCTAssertEqual(mockEnableCloudSync.startCallCount, 1)
        XCTAssertEqual(mockCloudSyncManager.checkCloudAvailabilityCallCount, 0)
    }

    func test_send_cloudAvailabilityRefresh_whileSynchronizing_doesNotRestartCoordinator() {
        // Given
        mockSettingsManager.isCloudSyncEnabled = true
        sut.send(.viewAppeared)
        _ = cloudSyncRuntimeStore.begin(.synchronizing)

        // When
        sut.send(.cloudAvailabilityRefresh)

        // Then
        XCTAssertEqual(mockEnableCloudSync.startCallCount, 0)
    }

    func test_send_cloudSyncConflictResolved_disableBeforeApply_cancelsWithoutRestartingCoordinator() async {
        // Given
        let gate = TestAsyncGate()
        mockSettingsManager.isCloudSyncEnabled = true
        mockUserProfileManager.resolveCloudSyncConflictHandler = { _ in
            await gate.wait()
        }
        sut.send(.viewAppeared)
        sut.send(.cloudSyncConflictResolved(keepLocal: true))
        await waitUntil { self.mockUserProfileManager.resolveCloudSyncConflictCallCount == 1 }

        // When
        sut.send(.cloudSyncToggled(false))
        await gate.open()
        await waitUntil { self.mockUserProfileManager.conflictCancellationCallCount == 1 }

        // Then
        XCTAssertNil(mockUserProfileManager.resolvedKeepLocal)
        XCTAssertNil(sut.cloudEnableTask)
        XCTAssertEqual(mockEnableCloudSync.startCallCount, 0)
        XCTAssertEqual(cloudSyncRuntimeStore.status, .disabled)
    }
}
