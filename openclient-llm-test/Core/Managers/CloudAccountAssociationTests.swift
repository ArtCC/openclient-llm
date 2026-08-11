//
//  CloudAccountAssociationTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudAccountAssociationTests: XCTestCase {
    func test_approveCurrentAccount_availableIdentity_persistsOnlySHA256Fingerprint() throws {
        // Given
        let suiteName = "CloudAccountAssociationTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let rawIdentity = Data("raw-ubiquity-identity".utf8)
        let rawIdentityString = try XCTUnwrap(String(data: rawIdentity, encoding: .utf8))
        let settings = SettingsManager(defaults: defaults, keychainManager: MockKeychainManager())
        let sut = CloudAccountAssociation(
            settingsManager: settings,
            containerProvider: FixedCloudContainerProvider(
                url: URL(fileURLWithPath: "/cloud"),
                identity: rawIdentity
            )
        )
        guard let fingerprint = sut.currentAccountFingerprint() else {
            return XCTFail("Expected fingerprint")
        }
        settings.setAcceptedCloudAccountFingerprint(rawIdentityString)
        XCTAssertNil(settings.getAcceptedCloudAccountFingerprint())

        // When
        try sut.approveCurrentAccount(expectedFingerprint: fingerprint)

        // Then
        XCTAssertEqual(settings.getAcceptedCloudAccountFingerprint(), fingerprint)
        XCTAssertEqual(fingerprint.count, 64)
        XCTAssertFalse(defaults.dictionaryRepresentation().values.contains { value in
            (value as? Data) == rawIdentity || (value as? String) == rawIdentityString
        })
    }

    func test_state_acceptedDifferentIdentity_returnsChangedWithoutReplacingFingerprint() throws {
        // Given
        let settings = MockSettingsManager()
        settings.acceptedCloudAccountFingerprint = "accepted-account"
        let sut = CloudAccountAssociation(
            settingsManager: settings,
            containerProvider: FixedCloudContainerProvider(
                url: URL(fileURLWithPath: "/cloud"),
                identity: Data("different-account".utf8)
            )
        )

        // When
        let state = sut.state()

        // Then
        XCTAssertEqual(state, .changed)
        XCTAssertEqual(settings.acceptedCloudAccountFingerprint, "accepted-account")
    }

    func test_setCloudSyncDisabled_existingAssociation_preservesFingerprint() {
        // Given
        let settings = MockSettingsManager()
        settings.isCloudSyncEnabled = true
        settings.acceptedCloudAccountFingerprint = "accepted-account"

        // When
        settings.setIsCloudSyncEnabled(false)

        // Then
        XCTAssertEqual(settings.acceptedCloudAccountFingerprint, "accepted-account")
    }
}
