//
//  ConversationCloudObserverTests+Enablement.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension ConversationCloudObserverTests {
    func test_startPreflightAfterMetadataBaseline_ready_executesInitialSynchronization() async {
        // Given
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        let preflight = MockEnableCloudSyncUseCase()
        let synchronizeAppData = MockSynchronizeAppDataUseCase()
        let runtimeStore = CloudSyncRuntimeStore()
        let metadataReadiness = CloudMetadataReadiness()
        let session = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/test-cloud"),
            identity: Data("test".utf8)
        )
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: synchronizeAppData,
            enableCloudSyncUseCase: preflight,
            notificationCenter: NotificationCenter(),
            metadataReadiness: metadataReadiness,
            containerProvider: FixedCloudContainerProvider(url: URL(fileURLWithPath: "/test-cloud")),
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore,
            accountAssociation: MockCloudAccountAssociation()
        )
        let runtimeGeneration = runtimeStore.begin(.checkingAvailability)
        sut.startGeneration = 1
        sut.runtimeGeneration = runtimeGeneration
        sut.startContext = .init(
            approvingCurrentAccount: false,
            approvalFingerprint: nil,
            generation: 1,
            runtimeGeneration: runtimeGeneration
        )
        sut.metadataSession = session
        sut.hasEstablishedBaseline = true
        metadataReadiness.setReady(for: session)

        // When
        sut.startPreflightAfterMetadataBaseline(for: session)
        while preflight.executeCallCount == 0 { await Task.yield() }
        while synchronizeAppData.executeCallCount == 0 { await Task.yield() }

        // Then
        XCTAssertEqual(preflight.executeCallCount, 1)
        XCTAssertEqual(synchronizeAppData.executeCallCount, 1)
        XCTAssertEqual(runtimeStore.status, .idle(lastSuccessfulSyncAt: nil))
    }

    func test_start_persistedIntentWithoutAssociation_requiresReviewWithoutPreflight() {
        // Given
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        let preflight = MockEnableCloudSyncUseCase()
        let association = MockCloudAccountAssociation()
        association.associationState = .unassociated
        let runtimeStore = CloudSyncRuntimeStore()
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: MockSynchronizeAppDataUseCase(),
            enableCloudSyncUseCase: preflight,
            notificationCenter: NotificationCenter(),
            metadataReadiness: CloudMetadataReadiness(),
            containerProvider: FixedCloudContainerProvider(url: URL(fileURLWithPath: "/test-cloud")),
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore,
            accountAssociation: association
        )

        // When
        sut.start()

        // Then
        XCTAssertEqual(preflight.executeCallCount, 0)
        XCTAssertEqual(association.approveCallCount, 0)
        XCTAssertEqual(runtimeStore.status, .failed(.init(
            reason: .accountChanged,
            affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
        )))
    }

    func test_approveCurrentAccount_pendingMetadata_doesNotPersistApproval() async {
        // Given
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        let preflight = MockEnableCloudSyncUseCase()
        preflight.result = .failure(CloudSyncPreflightError.issues(.init(
            pendingCategories: Set(CloudSyncStatus.DataCategory.allCases),
            unavailableCategories: [:],
            failureReasons: [:]
        )))
        let association = MockCloudAccountAssociation()
        association.associationState = .changed
        let metadataReadiness = CloudMetadataReadiness()
        let session = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/test-cloud"),
            identity: Data("test".utf8)
        )
        let runtimeStore = CloudSyncRuntimeStore()
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: MockSynchronizeAppDataUseCase(),
            enableCloudSyncUseCase: preflight,
            notificationCenter: NotificationCenter(),
            metadataReadiness: metadataReadiness,
            containerProvider: FixedCloudContainerProvider(url: URL(fileURLWithPath: "/test-cloud")),
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore,
            accountAssociation: association
        )
        let runtimeGeneration = runtimeStore.begin(.checkingAvailability)
        sut.startGeneration = 1
        sut.runtimeGeneration = runtimeGeneration
        sut.startContext = .init(
            approvingCurrentAccount: true,
            approvalFingerprint: association.fingerprint,
            generation: 1,
            runtimeGeneration: runtimeGeneration
        )
        sut.metadataSession = session
        sut.hasEstablishedBaseline = true
        metadataReadiness.setReady(for: session)

        // When
        sut.startPreflightAfterMetadataBaseline(for: session)
        while preflight.executeCallCount == 0 { await Task.yield() }
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertEqual(association.approveCallCount, 0)
        XCTAssertEqual(association.associationState, .changed)
    }

    func test_approveCurrentAccount_disabledDuringPreflight_doesNotPersistApproval() async {
        // Given
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        let gate = TestAsyncGate()
        let preflight = MockEnableCloudSyncUseCase()
        preflight.executeHandler = {
            await gate.wait()
            return .ready
        }
        let association = MockCloudAccountAssociation()
        association.associationState = .changed
        let metadataReadiness = CloudMetadataReadiness()
        let session = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/test-cloud"),
            identity: Data("test".utf8)
        )
        let runtimeStore = CloudSyncRuntimeStore()
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: MockSynchronizeAppDataUseCase(),
            enableCloudSyncUseCase: preflight,
            notificationCenter: NotificationCenter(),
            metadataReadiness: metadataReadiness,
            containerProvider: FixedCloudContainerProvider(url: URL(fileURLWithPath: "/test-cloud")),
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore,
            accountAssociation: association
        )
        let runtimeGeneration = runtimeStore.begin(.checkingAvailability)
        sut.startGeneration = 1
        sut.runtimeGeneration = runtimeGeneration
        sut.startContext = .init(
            approvingCurrentAccount: true,
            approvalFingerprint: association.fingerprint,
            generation: 1,
            runtimeGeneration: runtimeGeneration
        )
        sut.metadataSession = session
        sut.hasEstablishedBaseline = true
        metadataReadiness.setReady(for: session)
        sut.startPreflightAfterMetadataBaseline(for: session)
        while preflight.executeCallCount == 0 { await Task.yield() }

        // When
        settingsManager.isCloudSyncEnabled = false
        sut.stop()
        await gate.open()
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertEqual(association.approveCallCount, 0)
    }
}
