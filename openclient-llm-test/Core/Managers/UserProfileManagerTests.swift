//
//  UserProfileManagerTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class UserProfileManagerTests: XCTestCase {
    // MARK: - Properties

    private var documentsURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var settingsManager: MockSettingsManager!
    private var cloudSyncManager: MockCloudSyncManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defaultsSuiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        settingsManager = MockSettingsManager()
        cloudSyncManager = MockCloudSyncManager()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: documentsURL)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        documentsURL = nil
        defaults = nil
        defaultsSuiteName = nil
        settingsManager = nil
        cloudSyncManager = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_init_legacyBlob_writesValidProfileBeforeRemovingSource() throws {
        // Given
        let legacyData = Data(#"{"name":"Legacy","profileDescription":"Developer","extraInfo":"Swift"}"#.utf8)
        defaults.set(legacyData, forKey: "userProfile_data")

        // When
        let sut = makeManager()

        // Then
        XCTAssertEqual(sut.getLocalProfile().name, "Legacy")
        XCTAssertNil(defaults.data(forKey: "userProfile_data"))
    }

    func test_init_migrationWriteFails_retainsLegacySource() throws {
        // Given
        let legacyData = Data(#"{"name":"Legacy","profileDescription":"","extraInfo":""}"#.utf8)
        defaults.set(legacyData, forKey: "userProfile_data")
        let missingDirectory = documentsURL.appendingPathComponent("Missing", isDirectory: true)

        // When
        let sut = makeManager(documentsURL: missingDirectory)

        // Then
        XCTAssertEqual(defaults.data(forKey: "userProfile_data"), legacyData)
        XCTAssertNotNil(sut.migrationError)
    }

    func test_getCloudProfileState_remoteDeletion_preservesLocalProfileBeforeRemoval() async throws {
        // Given
        let sut = makeManager()
        let local = UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(local)
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 200)
        )
        cloudSyncManager.cloudProfileDeletionMarker = marker

        // When
        let state = try await sut.getCloudProfileState()

        // Then
        XCTAssertEqual(state, .deleted(marker))
        XCTAssertTrue(sut.getLocalProfile().isEmpty)
        let recoveryURL = documentsURL.appendingPathComponent("ProfileRecovery", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: recoveryURL.path).count, 1)
    }

    func test_resolveCloudSyncConflict_keepCloud_preservesLosingLocalProfile() async throws {
        // Given
        let sut = makeManager()
        let local = UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 100))
        let cloud = UserProfile(name: "Cloud", modifiedAt: Date(timeIntervalSince1970: 200))
        try await sut.saveProfile(local)
        cloudSyncManager.cloudProfile = cloud

        // When
        try await sut.resolveCloudSyncConflict(keepLocal: false)

        // Then
        XCTAssertEqual(sut.getLocalProfile(), cloud)
        let recoveryURL = documentsURL.appendingPathComponent("ProfileRecovery", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: recoveryURL.path).count, 1)
    }

    // MARK: - Private

    private func makeManager(documentsURL: URL? = nil) -> UserProfileManager {
        UserProfileManager(
            settingsManager: settingsManager,
            cloudSyncManager: cloudSyncManager,
            defaults: defaults,
            documentsURL: documentsURL ?? self.documentsURL
        )
    }
}
