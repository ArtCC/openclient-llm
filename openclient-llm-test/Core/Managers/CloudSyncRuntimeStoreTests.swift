//
//  CloudSyncRuntimeStoreTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudSyncRuntimeStoreTests: XCTestCase {
    func test_publish_eachAuthoritativeState_replacesCurrentState() {
        // Given
        let sut = CloudSyncRuntimeStore()
        let states: [CloudSyncStatus] = [
            .checkingAvailability,
            .idle(lastSuccessfulSyncAt: nil),
            .synchronizing,
            .waitingForDownloads,
            .synchronized(lastSuccessfulSyncAt: Date(timeIntervalSince1970: 100)),
            .unavailable(.accountUnavailable),
            .failed(.init(reason: .invalidData, affectedCategories: [.memory])),
            .disabled
        ]

        // When / Then
        for state in states {
            sut.publish(state)
            XCTAssertEqual(sut.status, state)
        }
    }

    func test_publish_staleGeneration_doesNotReplaceNewerOperation() {
        // Given
        let sut = CloudSyncRuntimeStore()
        let staleGeneration = sut.begin(.checkingAvailability)
        _ = sut.begin(.synchronizing)

        // When
        let didPublish = sut.publish(.unavailable(.containerUnavailable), generation: staleGeneration)

        // Then
        XCTAssertFalse(didPublish)
        XCTAssertEqual(sut.status, .synchronizing)
    }

    func test_init_enabledPersistedIntent_restoresIdleWithLastSuccess() {
        // Given
        let settingsManager = MockSettingsManager()
        let lastSuccess = Date(timeIntervalSince1970: 100)
        settingsManager.isCloudSyncEnabled = true
        settingsManager.lastSuccessfulCloudSyncDate = lastSuccess

        // When
        let sut = CloudSyncRuntimeStore(settingsManager: settingsManager)

        // Then
        XCTAssertEqual(sut.status, .idle(lastSuccessfulSyncAt: lastSuccess))
    }
}
