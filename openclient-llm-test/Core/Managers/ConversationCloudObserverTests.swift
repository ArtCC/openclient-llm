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
        let syncConversations = MockSyncConversationsUseCase()
        let notificationCenter = NotificationCenter()
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            syncConversationsUseCase: syncConversations,
            notificationCenter: notificationCenter,
            metadataReadiness: CloudMetadataReadiness(),
            metadataDebounceDuration: .zero
        )

        // When
        sut.handleMetadataChange()
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertEqual(syncConversations.executeCallCount, 0)
    }

    func test_handleMetadataChange_syncDisabled_doesNotSynchronize() async {
        // Given
        let settingsManager = MockSettingsManager()
        let syncConversations = MockSyncConversationsUseCase()
        let sut = ConversationCloudObserver(
            settingsManager: settingsManager,
            cloudSyncManager: MockCloudSyncManager(),
            syncConversationsUseCase: syncConversations,
            notificationCenter: NotificationCenter(),
            metadataReadiness: CloudMetadataReadiness(),
            metadataDebounceDuration: .zero
        )

        // When
        sut.handleMetadataChange()
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertEqual(syncConversations.executeCallCount, 0)
    }

    func test_stop_readyMetadata_marksMetadataNotReadyAndCancelsSynchronization() async {
        // Given
        let metadataReadiness = CloudMetadataReadiness()
        let session = CloudSyncSession(
            containerURL: URL(fileURLWithPath: "/test-cloud"),
            identity: Data("test".utf8)
        )
        metadataReadiness.setReady(for: session)
        let syncConversations = MockSyncConversationsUseCase()
        let sut = ConversationCloudObserver(
            settingsManager: MockSettingsManager(),
            cloudSyncManager: MockCloudSyncManager(),
            syncConversationsUseCase: syncConversations,
            notificationCenter: NotificationCenter(),
            metadataReadiness: metadataReadiness,
            metadataDebounceDuration: .zero
        )

        // When
        sut.stop()
        for _ in 0..<10 { await Task.yield() }

        // Then
        XCTAssertFalse(metadataReadiness.isReady(for: session))
        XCTAssertEqual(syncConversations.cancelCallCount, 1)
    }
}
