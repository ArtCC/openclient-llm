//
//  UserProfileManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol UserProfileManagerProtocol: Sendable {
    func getProfile() -> UserProfile
    func saveProfile(_ profile: UserProfile) async throws
    func getLocalProfile() -> UserProfile
    func getLocalProfileState() throws -> LocalUserProfileState
    func getCloudProfileState() async throws -> CloudUserProfileState
    func resolveCloudSyncConflict(keepLocal: Bool) async throws
    func deleteProfile() async throws
    func deleteSynchronizedProfile() async throws
    func deleteLocalProfile() throws
    func purgeLocalProfile(through marker: CloudPurgeMarker) throws
    func validateLocalReset() throws
}

protocol LegacyUserProfileCloudStore {
    func string(forKey key: String) -> String?
    func removeObject(forKey key: String)
    func synchronize()
}

struct UbiquitousLegacyUserProfileCloudStore: LegacyUserProfileCloudStore {
    func string(forKey key: String) -> String? {
        NSUbiquitousKeyValueStore.default.string(forKey: key)
    }

    func removeObject(forKey key: String) {
        NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
    }

    func synchronize() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

/// Manages the user's personal context with optional iCloud file-based sync.
///
/// When iCloud sync is enabled the cloud `UserProfile.json` is the single source of truth.
/// Local storage is a JSON file in DocumentDirectory and is used when sync is disabled.
///
/// Safety: FileManager operations are thread-safe for different paths. Cloud operations are async,
/// and mutable manager state is accessed from the app's default main actor.
final class UserProfileManager: UserProfileManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    enum Keys {
        static let legacyProfileData = "userProfile_data"
    }

    static let fileName = "UserProfile.json"

    /// Notification posted when iCloud pushes an external profile change.
    nonisolated static let profileDidChangeExternallyNotification = Notification.Name(
        "UserProfileManager.profileDidChangeExternally"
    )

    let settingsManager: SettingsManagerProtocol
    let cloudSyncManager: CloudSyncManagerProtocol
    let mutationGate: CloudSynchronizationMutationGate
    let defaults: UserDefaults
    let legacyCloudStore: LegacyUserProfileCloudStore
    let localFileURL: URL?
    let localDeletionFileURL: URL?
    let recoveryDirectoryURL: URL?
    private(set) var migrationError: Error?

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        defaults: UserDefaults = .standard,
        legacyCloudStore: LegacyUserProfileCloudStore = UbiquitousLegacyUserProfileCloudStore(),
        documentsURL: URL? = nil,
        mutationGate: CloudSynchronizationMutationGate = .shared
    ) {
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.mutationGate = mutationGate
        self.defaults = defaults
        self.legacyCloudStore = legacyCloudStore
        let resolvedDocumentsURL = documentsURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.localFileURL = resolvedDocumentsURL?.appendingPathComponent(Self.fileName)
        self.localDeletionFileURL = resolvedDocumentsURL?.appendingPathComponent("UserProfileDeletion.json")
        self.recoveryDirectoryURL = resolvedDocumentsURL?.appendingPathComponent("ProfileRecovery", isDirectory: true)
        do {
            try migrateFromUserDefaultsIfNeeded()
            try migrateLegacyKeysIfNeeded()
        } catch {
            migrationError = error
            LogManager.error("User profile migration failed; legacy source data was retained.")
        }
    }

    // MARK: - Public

    func getProfile() -> UserProfile {
        return getLocalProfile()
    }

    func saveProfile(_ profile: UserProfile) async throws {
        var canonicalProfile = profile
        canonicalProfile.modifiedAt = UserProfile.canonicalRevision(profile.modifiedAt)
        let profile = canonicalProfile
        let requiredCloudIntent = settingsManager.getIsCloudSyncEnabled()
        guard requiredCloudIntent else {
            try saveToLocal(profile)
            return
        }
        try await mutationGate.perform {
            try await self.checkCloudIntent(requiredCloudIntent)
            try await self.saveProfileSerialized(profile, requiredCloudIntent: requiredCloudIntent)
        }
    }

    func getLocalProfile() -> UserProfile {
        guard case .profile(let profile) = try? getLocalProfileState() else {
            return UserProfile(modifiedAt: .distantPast)
        }
        return profile
    }

    func getLocalProfileState() throws -> LocalUserProfileState {
        guard let url = localFileURL else { throw CloudSyncError.invalidProfileData }
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        do {
            return .profile(try makeDecoder().decode(UserProfile.self, from: Data(contentsOf: url)))
        } catch {
            throw CloudSyncError.invalidProfileData
        }
    }

    func getCloudProfileState() async throws -> CloudUserProfileState {
        let snapshot = try await cloudSyncManager.loadProfileSyncSnapshot()
        return snapshot.state
    }

    func resolveCloudSyncConflict(keepLocal: Bool) async throws {
        let requiredCloudIntent = settingsManager.getIsCloudSyncEnabled()
        guard requiredCloudIntent else { throw CancellationError() }
        try await mutationGate.perform {
            try await self.checkCloudIntent(requiredCloudIntent)
            try await self.resolveCloudSyncConflictSerialized(
                keepLocal: keepLocal,
                requiredCloudIntent: requiredCloudIntent
            )
        }
    }

}
