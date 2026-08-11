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
    private var legacyCloudStore: MockLegacyUserProfileCloudStore!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        documentsURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        defaultsSuiteName = UUID().uuidString
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        settingsManager = MockSettingsManager()
        cloudSyncManager = MockCloudSyncManager()
        legacyCloudStore = MockLegacyUserProfileCloudStore()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: documentsURL)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        documentsURL = nil
        defaults = nil
        defaultsSuiteName = nil
        settingsManager = nil
        cloudSyncManager = nil
        legacyCloudStore = nil
        try await super.tearDown()
    }
}

// MARK: - Tests

extension UserProfileManagerTests {
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

    func test_init_legacyKeys_migratesWithOldestRevisionBeforeRemovingSource() {
        // Given
        defaults.set("Legacy", forKey: "userProfile_name")
        defaults.set("Developer", forKey: "userProfile_description")

        // When
        let sut = makeManager()

        // Then
        XCTAssertEqual(
            sut.getLocalProfile(),
            UserProfile(name: "Legacy", profileDescription: "Developer", modifiedAt: .distantPast)
        )
        XCTAssertNil(defaults.string(forKey: "userProfile_name"))
        XCTAssertNil(defaults.string(forKey: "userProfile_description"))
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

    func test_getLocalProfileState_missingAndValidEmpty_distinguishesExistence() async throws {
        // Given
        let sut = makeManager()

        // When
        let missingState = try sut.getLocalProfileState()
        let empty = UserProfile(modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(empty)

        // Then
        XCTAssertEqual(missingState, .missing)
        XCTAssertEqual(try sut.getLocalProfileState(), .profile(empty))
    }

    func test_resolveCloudSyncConflict_corruptLocalProfile_reportsInvalidDataWithoutChangingBytes() async throws {
        // Given
        let corruptData = Data("not-json".utf8)
        let profileURL = documentsURL.appendingPathComponent("UserProfile.json")
        try corruptData.write(to: profileURL)
        let cloud = UserProfile(name: "Cloud", modifiedAt: Date(timeIntervalSince1970: 200))
        cloudSyncManager.cloudProfile = cloud
        settingsManager.isCloudSyncEnabled = true
        let sut = makeManager()

        // When
        do {
            try await sut.resolveCloudSyncConflict(keepLocal: false)
            XCTFail("Expected invalid local profile data")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .invalidProfileData)
            XCTAssertEqual(try Data(contentsOf: profileURL), corruptData)
            XCTAssertEqual(cloudSyncManager.cloudProfile, cloud)
            XCTAssertEqual(cloudSyncManager.applyProfileCallCount, 0)
        }
    }

    func test_resolveCloudSyncConflict_disabledWhileLoading_doesNotApplyCloudOutput() async throws {
        // Given
        let gate = TestAsyncGate()
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.loadProfileHandler = { await gate.wait() }
        let sut = makeManager()
        let resolutionTask = Task {
            try await sut.resolveCloudSyncConflict(keepLocal: true)
        }
        while cloudSyncManager.loadProfileCallCount == 0 { await Task.yield() }

        // When
        settingsManager.isCloudSyncEnabled = false
        await gate.open()

        // Then
        do {
            try await resolutionTask.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(cloudSyncManager.applyProfileCallCount, 0)
        }
    }

    func test_resolveCloudSyncConflict_remoteDeletion_preservesLocalProfileBeforeRemoval() async throws {
        // Given
        let sut = makeManager()
        let local = UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(local)
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 200)
        )
        cloudSyncManager.cloudProfileDeletionMarker = marker
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.resolveCloudSyncConflict(keepLocal: true)

        // Then
        XCTAssertTrue(sut.getLocalProfile().isEmpty)
        let recoveryURL = documentsURL.appendingPathComponent("ProfileRecovery", isDirectory: true)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: recoveryURL.path).count, 1)
    }

    func test_resolveCloudSyncConflict_remoteDeletion_preservesValidEmptyProfileBeforeRemoval() async throws {
        // Given
        let sut = makeManager()
        let local = UserProfile(modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(local)
        cloudSyncManager.cloudProfileDeletionMarker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: Date(timeIntervalSince1970: 200)
        )
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.resolveCloudSyncConflict(keepLocal: true)

        // Then
        XCTAssertEqual(try sut.getLocalProfileState(), .missing)
        XCTAssertEqual(try recoveredProfiles(), [local])
    }

    func test_saveProfile_dateNow_persistsCanonicalRevisionWithoutFailure() async throws {
        // Given
        let sut = makeManager()
        let profile = UserProfile(name: "Current")
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.saveProfile(profile)

        // Then
        XCTAssertEqual(sut.getLocalProfile().name, profile.name)
        XCTAssertEqual(
            sut.getLocalProfile().modifiedAt.timeIntervalSince1970,
            profile.modifiedAt.timeIntervalSince1970,
            accuracy: 0.000001
        )
        XCTAssertEqual(cloudSyncManager.savedProfile, sut.getLocalProfile())
    }

    func test_saveProfile_preflightPending_performsNoLocalWrite() async throws {
        // Given
        let sut = makeManager()
        let original = UserProfile(name: "Original", modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(original)
        settingsManager.isCloudSyncEnabled = true
        cloudSyncManager.loadError = CloudSyncError.requiredDownloadPending

        // When
        do {
            try await sut.saveProfile(UserProfile(name: "Unready", modifiedAt: Date(timeIntervalSince1970: 200)))
            XCTFail("Expected pending preflight")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .requiredDownloadPending)
            XCTAssertEqual(sut.getLocalProfile(), original)
            XCTAssertEqual(cloudSyncManager.applyProfileCallCount, 0)
        }
    }

    func test_saveProfile_cloudChangesDuringApply_reloadsAndReconcilesBeforeRetry() async throws {
        // Given
        let sut = makeManager()
        let originalCloud = UserProfile(name: "Original Cloud", modifiedAt: Date(timeIntervalSince1970: 100))
        let concurrentCloud = UserProfile(name: "Concurrent Cloud", modifiedAt: Date(timeIntervalSince1970: 200))
        let saved = UserProfile(name: "Saved", modifiedAt: Date(timeIntervalSince1970: 300))
        cloudSyncManager.cloudProfile = originalCloud
        cloudSyncManager.applyProfileHandler = { [cloudSyncManager] in
            cloudSyncManager?.cloudProfile = concurrentCloud
            cloudSyncManager?.applyProfileHandler = nil
        }
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.saveProfile(saved)

        // Then
        XCTAssertEqual(cloudSyncManager.applyProfileCallCount, 2)
        XCTAssertEqual(cloudSyncManager.cloudProfile, saved)
        XCTAssertEqual(sut.getLocalProfile(), saved)
        XCTAssertEqual(Set(try recoveredProfiles().map(\.name)), Set([originalCloud.name, concurrentCloud.name]))
    }

    func test_saveProfile_equalRevisionConflict_preservesBothRepresentations() async throws {
        // Given
        let sut = makeManager()
        let revision = Date(timeIntervalSince1970: 100)
        let local = UserProfile(name: "Local", modifiedAt: revision)
        let cloud = UserProfile(name: "Cloud", modifiedAt: revision)
        try await sut.saveProfile(local)
        cloudSyncManager.cloudProfile = cloud
        settingsManager.isCloudSyncEnabled = true

        // When
        do {
            try await sut.saveProfile(local)
            XCTFail("Expected explicit profile conflict")
        } catch {
            // Then
            XCTAssertEqual(error as? CloudSyncError, .conflictingProfileRevision)
            XCTAssertEqual(sut.getLocalProfile(), local)
            XCTAssertEqual(cloudSyncManager.cloudProfile, cloud)
            XCTAssertEqual(Set(try recoveredProfiles().map(\.name)), Set([local.name, cloud.name]))
        }
    }

    func test_saveProfile_repeatedEqualRevisionConflict_writesEachRepresentationOnce() async throws {
        // Given
        let sut = makeManager()
        let revision = Date(timeIntervalSince1970: 100)
        let local = UserProfile(name: "Local", modifiedAt: revision)
        let cloud = UserProfile(name: "Cloud", modifiedAt: revision)
        try await sut.saveProfile(local)
        cloudSyncManager.cloudProfile = cloud
        settingsManager.isCloudSyncEnabled = true

        // When
        for _ in 0..<2 {
            do {
                try await sut.saveProfile(local)
                XCTFail("Expected explicit profile conflict")
            } catch {
                XCTAssertEqual(error as? CloudSyncError, .conflictingProfileRevision)
            }
        }

        // Then
        XCTAssertEqual(Set(try recoveredProfiles().map(\.name)), Set([local.name, cloud.name]))
        XCTAssertEqual(try recoveredProfiles().count, 2)
    }

    func test_legacyCloudKeys_migrationRetainsUntilVerifiedCloudSync() async throws {
        // Given
        legacyCloudStore.values = [
            "userProfile_name": "Legacy",
            "userProfile_description": "Developer"
        ]
        let sut = makeManager()

        cloudSyncManager.syncError = CloudSyncError.containerUnavailable
        settingsManager.isCloudSyncEnabled = true
        var profile = sut.getLocalProfile()
        profile.modifiedAt = Date(timeIntervalSince1970: 100)
        try? await sut.saveProfile(profile)
        let retainedAfterFailedSync = legacyCloudStore.values
        cloudSyncManager.syncError = nil

        // When
        try await sut.saveProfile(profile)

        // Then
        XCTAssertEqual(retainedAfterFailedSync["userProfile_name"], "Legacy")
        XCTAssertTrue(legacyCloudStore.values.isEmpty)
        XCTAssertEqual(legacyCloudStore.synchronizeCallCount, 1)
        XCTAssertEqual(cloudSyncManager.cloudProfile, profile)
    }

    func test_resolveCloudSyncConflict_localOnly_uploadsLocalProfile() async throws {
        // Given
        let sut = makeManager()
        let local = UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 100))
        settingsManager.isCloudSyncEnabled = false
        try await sut.saveProfile(local)
        settingsManager.isCloudSyncEnabled = true

        // When
        let cloudState = try await sut.getCloudProfileState()
        try await sut.resolveCloudSyncConflict(keepLocal: true)

        // Then
        XCTAssertEqual(cloudState, .missing)
        XCTAssertEqual(cloudSyncManager.savedProfile, sut.getLocalProfile())
        XCTAssertGreaterThan(sut.getLocalProfile().modifiedAt, local.modifiedAt)
    }

    func test_resolveCloudSyncConflict_cloudOnly_downloadsCloudProfile() async throws {
        // Given
        let sut = makeManager()
        let cloud = UserProfile(name: "Cloud", modifiedAt: Date(timeIntervalSince1970: 200))
        cloudSyncManager.cloudProfile = cloud
        settingsManager.isCloudSyncEnabled = true

        // When
        let cloudState = try await sut.getCloudProfileState()
        try await sut.resolveCloudSyncConflict(keepLocal: false)

        // Then
        XCTAssertEqual(cloudState, .profile(cloud))
        XCTAssertEqual(sut.getLocalProfile(), cloud)
    }

    func test_resolveCloudSyncConflict_newerLocal_uploadsLocalAndPreservesCloud() async throws {
        // Given
        let sut = makeManager()
        let local = UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 200))
        let cloud = UserProfile(name: "Cloud", modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(local)
        cloudSyncManager.cloudProfile = cloud
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.resolveCloudSyncConflict(keepLocal: true)

        // Then
        XCTAssertEqual(cloudSyncManager.savedProfile, sut.getLocalProfile())
        XCTAssertEqual(try recoveredProfiles(), [cloud])
    }

    func test_resolveCloudSyncConflict_newerCloud_preservesLosingLocalProfile() async throws {
        // Given
        let sut = makeManager()
        let local = UserProfile(name: "Local", modifiedAt: Date(timeIntervalSince1970: 100))
        let cloud = UserProfile(name: "Cloud", modifiedAt: Date(timeIntervalSince1970: 200))
        try await sut.saveProfile(local)
        cloudSyncManager.cloudProfile = cloud
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.resolveCloudSyncConflict(keepLocal: false)

        // Then
        XCTAssertEqual(sut.getLocalProfile(), cloud)
        XCTAssertEqual(try recoveredProfiles(), [local])
    }

    func test_saveProfile_equalCloudProfile_keepsSameRepresentationWithoutRecovery() async throws {
        // Given
        let sut = makeManager()
        let profile = UserProfile(name: "Same", modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(profile)
        cloudSyncManager.cloudProfile = profile
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.saveProfile(profile)

        // Then
        XCTAssertEqual(sut.getLocalProfile(), profile)
        XCTAssertEqual(cloudSyncManager.savedProfile, profile)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: documentsURL.appendingPathComponent("ProfileRecovery", isDirectory: true).path
        ))
    }

    func test_resolveCloudSyncConflict_equalRevisionKeepLocal_preservesCloudAndAdvancesRevision() async throws {
        // Given
        let sut = makeManager()
        let revision = Date(timeIntervalSince1970: 100)
        let local = UserProfile(name: "Local", modifiedAt: revision)
        let cloud = UserProfile(name: "Cloud", modifiedAt: revision)
        try await sut.saveProfile(local)
        cloudSyncManager.cloudProfile = cloud
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.resolveCloudSyncConflict(keepLocal: true)

        // Then
        XCTAssertEqual(sut.getLocalProfile().name, local.name)
        XCTAssertGreaterThan(sut.getLocalProfile().modifiedAt, revision)
        XCTAssertEqual(cloudSyncManager.savedProfile, sut.getLocalProfile())
        XCTAssertEqual(try recoveredProfiles(), [cloud])
    }

    func test_deleteProfile_cloudEnabled_writesDurableMarkerBeforeRemovingPayload() async throws {
        // Given
        let sut = makeManager()
        let profile = UserProfile(name: "Delete", modifiedAt: Date(timeIntervalSince1970: 100))
        try await sut.saveProfile(profile)
        cloudSyncManager.cloudProfile = profile
        settingsManager.isCloudSyncEnabled = true

        // When
        try await sut.deleteProfile()

        // Then
        let marker = try XCTUnwrap(cloudSyncManager.cloudProfileDeletionMarker)
        XCTAssertGreaterThan(marker.deletedAt, profile.modifiedAt)
        XCTAssertNil(cloudSyncManager.cloudProfile)
        XCTAssertEqual(try sut.getLocalProfileState(), .missing)
    }
}

// MARK: - Private

private extension UserProfileManagerTests {
    private func makeManager(documentsURL: URL? = nil) -> UserProfileManager {
        UserProfileManager(
            settingsManager: settingsManager,
            cloudSyncManager: cloudSyncManager,
            defaults: defaults,
            legacyCloudStore: legacyCloudStore,
            documentsURL: documentsURL ?? self.documentsURL
        )
    }

    private func recoveredProfiles() throws -> [UserProfile] {
        let recoveryURL = documentsURL.appendingPathComponent("ProfileRecovery", isDirectory: true)
        let urls = try FileManager.default.contentsOfDirectory(
            at: recoveryURL,
            includingPropertiesForKeys: nil
        )
        let decoder = SyncJSONCoding.makeDecoder()
        return try urls.map { try decoder.decode(UserProfile.self, from: Data(contentsOf: $0)) }
    }
}

@MainActor
private final class MockLegacyUserProfileCloudStore: LegacyUserProfileCloudStore {
    var values: [String: String] = [:]
    var synchronizeCallCount = 0

    func string(forKey key: String) -> String? {
        values[key]
    }

    func removeObject(forKey key: String) {
        values.removeValue(forKey: key)
    }

    func synchronize() {
        synchronizeCallCount += 1
    }
}
