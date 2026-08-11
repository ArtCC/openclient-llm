//
//  ConversationCloudObserverTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationCloudObserverTests: XCTestCase {
    func test_synchronizedPathComponents_includeAllPayloadAndDeletionMetadata() {
        // Given / When
        let paths = Set(ConversationCloudObserver.synchronizedPathComponents)

        // Then
        XCTAssertEqual(paths, [
            "SyncManifest.json",
            "CloudPurgeMarker.json",
            "UserProfile.json",
            "UserProfileDeletion.json",
            "Memory.json",
            "MemoryTombstones.json",
            "/PromptTemplates",
            "/PromptTemplateTombstones",
            "/Conversations",
            "/ConversationTombstones",
            "ConversationTombstones.json",
            "ConversationDeleteAll.json",
            "/Attachments"
        ])
    }

    func test_requiresDownload_nonCurrentStatus_returnsTrue() {
        // Given / When / Then
        XCTAssertTrue(ConversationCloudObserver.requiresDownload(
            forDownloadingStatus: NSMetadataUbiquitousItemDownloadingStatusNotDownloaded
        ))
        XCTAssertTrue(ConversationCloudObserver.requiresDownload(
            forDownloadingStatus: NSMetadataUbiquitousItemDownloadingStatusDownloaded
        ))
        XCTAssertFalse(ConversationCloudObserver.requiresDownload(
            forDownloadingStatus: NSMetadataUbiquitousItemDownloadingStatusCurrent
        ))
        XCTAssertFalse(ConversationCloudObserver.requiresDownload(forDownloadingStatus: nil))
    }

    func test_metadataReadiness_differentIdentity_isNotReady() {
        // Given
        let sut = CloudMetadataReadiness()
        let first = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/cloud"),
            identity: Data("A".utf8)
        )
        let second = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/cloud"),
            identity: Data("B".utf8)
        )
        sut.setReady(for: first)

        // When / Then
        XCTAssertTrue(sut.isReady(for: first))
        XCTAssertFalse(sut.isReady(for: second))
    }

    func test_metadataReadiness_resetForDifferentSession_keepsReadySession() {
        // Given
        let sut = CloudMetadataReadiness()
        let readySession = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/cloud"),
            identity: Data("A".utf8)
        )
        let staleSession = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/cloud"),
            identity: Data("B".utf8)
        )
        sut.setReady(for: readySession)

        // When
        sut.reset(for: staleSession)

        // Then
        XCTAssertTrue(sut.isReady(for: readySession))
    }

    func test_ubiquityProvider_usesInjectedMetadataReadiness() {
        // Given
        let readiness = CloudMetadataReadiness()
        let session = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/cloud"),
            identity: Data("A".utf8)
        )
        let sut = UbiquityCloudContainerProvider(
            fileManager: .default,
            metadataReadiness: readiness
        )

        // When
        readiness.setReady(for: session)

        // Then
        XCTAssertTrue(sut.isMetadataReady(for: session))
    }

    func test_handleMetadataChange_withoutEstablishedBaseline_doesNotSynchronize() async {
        // Given
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        let synchronizeAppData = MockSynchronizeAppDataUseCase()
        let notificationCenter = NotificationCenter()
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: synchronizeAppData,
            notificationCenter: notificationCenter,
            metadataReadiness: CloudMetadataReadiness(),
            metadataDebounceDuration: .zero
        )

        // When
        sut.handleMetadataChange()
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertEqual(synchronizeAppData.executeCallCount, 0)
    }

    func test_handleMetadataChange_syncDisabled_doesNotSynchronize() async {
        // Given
        let settingsManager = MockSettingsManager()
        let synchronizeAppData = MockSynchronizeAppDataUseCase()
        let runtimeStore = CloudSyncRuntimeStore(status: .synchronizing)
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: synchronizeAppData,
            notificationCenter: NotificationCenter(),
            metadataReadiness: CloudMetadataReadiness(),
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore
        )

        // When
        sut.handleMetadataChange()
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertEqual(synchronizeAppData.executeCallCount, 0)
    }

    func test_stop_readyMetadata_marksMetadataNotReadyAndCancelsSynchronization() async {
        // Given
        let metadataReadiness = CloudMetadataReadiness()
        let session = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/test-cloud"),
            identity: Data("test".utf8)
        )
        metadataReadiness.setReady(for: session)
        let synchronizeAppData = MockSynchronizeAppDataUseCase()
        let runtimeStore = CloudSyncRuntimeStore(status: .synchronizing)
        let sut = ConversationCloudObserver(
            settingsManager: MockSettingsManager(),
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: synchronizeAppData,
            notificationCenter: NotificationCenter(),
            metadataReadiness: metadataReadiness,
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore
        )

        // When
        sut.stop()
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertFalse(metadataReadiness.isReady(for: session))
        XCTAssertEqual(synchronizeAppData.cancelCallCount, 1)
        XCTAssertEqual(runtimeStore.status, .disabled)
    }

    func test_synchronizeDetectedChanges_executesGlobalSyncAndNotifiesSuccessfulCategories() async {
        // Given
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        let synchronizeAppData = MockSynchronizeAppDataUseCase()
        synchronizeAppData.result = AppSynchronizationResult(outcomes: [
            .conversations: .synchronized,
            .profile: .failed,
            .memory: .synchronized,
            .promptTemplates: .synchronized
        ])
        let notificationCenter = NotificationCenter()
        let runtimeStore = CloudSyncRuntimeStore(status: .synchronizing)
        let recorder = NotificationRecorder()
        let names = [
            Notification.Name.conversationDidUpdate,
            UserProfileManager.profileDidChangeExternallyNotification,
            MemoryManager.memoryDidChangeExternallyNotification,
            .promptTemplatesDidChangeExternally
        ]
        let observers = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { recorder.names.append(name) }
            }
        }
        defer { observers.forEach(notificationCenter.removeObserver) }
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: synchronizeAppData,
            notificationCenter: notificationCenter,
            metadataReadiness: CloudMetadataReadiness(),
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore
        )

        // When
        sut.synchronizeDetectedChanges()
        while synchronizeAppData.executeCallCount == 0 { await Task.yield() }
        while recorder.names.count < 3 { await Task.yield() }

        // Then
        XCTAssertEqual(synchronizeAppData.executeCallCount, 1)
        XCTAssertEqual(Set(recorder.names), [
            .conversationDidUpdate,
            MemoryManager.memoryDidChangeExternallyNotification,
            .promptTemplatesDidChangeExternally
        ])
        XCTAssertEqual(runtimeStore.status, .synchronizing)
    }

    func test_start_persistedIntent_waitsForPreflightBeforeSynchronization() async {
        // Given
        let settingsManager = MockSettingsManager()
        settingsManager.isCloudSyncEnabled = true
        let preflight = MockEnableCloudSyncUseCase()
        let gate = TestAsyncGate()
        preflight.executeHandler = {
            await gate.wait()
            return .ready
        }
        let synchronizeAppData = MockSynchronizeAppDataUseCase()
        let runtimeStore = CloudSyncRuntimeStore()
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: synchronizeAppData,
            enableCloudSyncUseCase: preflight,
            notificationCenter: NotificationCenter(),
            metadataReadiness: CloudMetadataReadiness(),
            containerProvider: FixedCloudContainerProvider(url: URL(fileURLWithPath: "/test-cloud")),
            metadataDebounceDuration: .zero,
            runtimeStore: runtimeStore,
            accountAssociation: MockCloudAccountAssociation()
        )

        // When
        sut.start()
        while preflight.executeCallCount == 0 { await Task.yield() }

        // Then
        XCTAssertEqual(synchronizeAppData.executeCallCount, 0)
        settingsManager.isCloudSyncEnabled = false
        sut.stop()
        await gate.open()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(synchronizeAppData.executeCallCount, 0)
        XCTAssertEqual(runtimeStore.status, .disabled)
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
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: MockSynchronizeAppDataUseCase(),
            enableCloudSyncUseCase: preflight,
            notificationCenter: NotificationCenter(),
            metadataReadiness: CloudMetadataReadiness(),
            containerProvider: FixedCloudContainerProvider(url: URL(fileURLWithPath: "/test-cloud")),
            metadataDebounceDuration: .zero,
            runtimeStore: CloudSyncRuntimeStore(),
            accountAssociation: association
        )

        // When
        sut.approveCurrentAccount()
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
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: MockSynchronizeAppDataUseCase(),
            enableCloudSyncUseCase: preflight,
            notificationCenter: NotificationCenter(),
            metadataReadiness: CloudMetadataReadiness(),
            containerProvider: FixedCloudContainerProvider(url: URL(fileURLWithPath: "/test-cloud")),
            metadataDebounceDuration: .zero,
            runtimeStore: CloudSyncRuntimeStore(),
            accountAssociation: association
        )
        sut.approveCurrentAccount()
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

@MainActor
private final class NotificationRecorder {
    var names: [Notification.Name] = []
}
