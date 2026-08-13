//
//  SettingsManagerCloudSyncTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SettingsManagerCloudSyncTests: XCTestCase {
    func test_lastSuccessfulCloudSyncDate_roundTripsAndDeleteAllClearsIt() {
        // Given
        let suiteName = "SettingsManagerCloudSyncTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let sut = SettingsManager(defaults: defaults, keychainManager: MockKeychainManager())
        let date = Date(timeIntervalSince1970: 100)

        // When
        sut.setLastSuccessfulCloudSyncDate(date)

        // Then
        XCTAssertEqual(sut.getLastSuccessfulCloudSyncDate(), date)
        sut.deleteAll()
        XCTAssertNil(sut.getLastSuccessfulCloudSyncDate())
    }
}
