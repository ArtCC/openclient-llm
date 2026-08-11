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
        await waitUntil { self.mockSynchronizeAppData.executeCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
        XCTAssertTrue(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertEqual(mockSynchronizeAppData.executeCallCount, 1)
    }

    func test_send_cloudSyncToggled_disablesSyncAfterCancellationQuiesces() async {
        // Given
        mockSettingsManager.isCloudSyncEnabled = true
        sut.send(.viewAppeared)
        let gate = TestAsyncGate()
        mockSynchronizeAppData.cancelHandler = { await gate.wait() }

        // When
        sut.send(.cloudSyncToggled(false))
        await waitUntil { self.mockSynchronizeAppData.cancelCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isCloudSyncEnabled)
        XCTAssertFalse(mockSettingsManager.isCloudSyncEnabled)
        await gate.open()
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isCloudSyncEnabled
        }
    }

    func test_send_cloudSyncToggled_profileDownloadPending_keepsIntentDisabledAndShowsPending() async {
        // Given
        mockUserProfileManager.cloudError = CloudSyncError.requiredDownloadPending
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockUserProfileManager.getCloudProfileCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isCloudSyncEnabled)
        XCTAssertFalse(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertNil(mockUserProfileManager.resolvedKeepLocal)
        XCTAssertEqual(mockSynchronizeAppData.executeCallCount, 0)
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
}
