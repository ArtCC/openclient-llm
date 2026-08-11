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
    func getCloudProfileState() async throws -> CloudUserProfileState
    func getCloudProfile() async throws -> UserProfile?
    func resolveCloudSyncConflict(keepLocal: Bool) async throws
    func deleteLocalProfile() throws
}

/// Manages the user's personal context with optional iCloud file-based sync.
///
/// When iCloud sync is enabled the cloud `UserProfile.json` is the single source of truth.
/// Local storage is a JSON file in DocumentDirectory and is used when sync is disabled.
///
/// Safety: FileManager operations are thread-safe for different paths. Cloud operations are async.
/// NSMetadataQuery state is created, observed, and stopped only on the main actor.
final class UserProfileManager: UserProfileManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let legacyProfileData = "userProfile_data"
    }

    private static let fileName = "UserProfile.json"

    /// Notification posted when iCloud pushes an external profile change.
    nonisolated static let profileDidChangeExternallyNotification = Notification.Name(
        "UserProfileManager.profileDidChangeExternally"
    )

    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private let defaults: UserDefaults
    private let localFileURL: URL?
    private let recoveryDirectoryURL: URL?
    private(set) var migrationError: Error?
    private nonisolated(unsafe) var metadataQuery: NSMetadataQuery?
    // Must be stored to keep the observer alive.
    private nonisolated(unsafe) var queryObserver: NSObjectProtocol?

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        defaults: UserDefaults = .standard,
        documentsURL: URL? = nil
    ) {
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.defaults = defaults
        let resolvedDocumentsURL = documentsURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.localFileURL = resolvedDocumentsURL?.appendingPathComponent(Self.fileName)
        self.recoveryDirectoryURL = resolvedDocumentsURL?.appendingPathComponent("ProfileRecovery", isDirectory: true)
        do {
            try migrateFromUserDefaultsIfNeeded()
            try migrateLegacyKeysIfNeeded()
        } catch {
            migrationError = error
            LogManager.error("User profile migration failed; legacy source data was retained.")
        }
        startMonitoringCloudFile()
    }

    deinit {
        metadataQuery?.stop()
        if let queryObserver {
            NotificationCenter.default.removeObserver(queryObserver)
        }
    }

    // MARK: - Public

    func getProfile() -> UserProfile {
        return getLocalProfile()
    }

    func saveProfile(_ profile: UserProfile) async throws {
        try saveToLocal(profile)
        guard settingsManager.getIsCloudSyncEnabled() else { return }
        let cloudState = try await cloudSyncManager.loadProfileStateFromCloud()
        try reconcileBeforeSaving(profile, with: cloudState)
        try await cloudSyncManager.saveProfileToCloud(profile)
    }

    func getLocalProfile() -> UserProfile {
        guard let url = localFileURL,
              let data = try? Data(contentsOf: url),
              let profile = try? makeDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile(modifiedAt: .distantPast)
        }
        return profile
    }

    func getCloudProfileState() async throws -> CloudUserProfileState {
        let state = try await cloudSyncManager.loadProfileStateFromCloud()
        if case .deleted(let marker) = state {
            try applyRemoteDeletion(marker)
        }
        return state
    }

    func getCloudProfile() async throws -> UserProfile? {
        switch try await getCloudProfileState() {
        case .missing, .deleted:
            nil
        case .profile(let profile):
            profile
        }
    }

    func resolveCloudSyncConflict(keepLocal: Bool) async throws {
        if keepLocal {
            let state = try await cloudSyncManager.loadProfileStateFromCloud()
            if case .deleted(let marker) = state, getLocalProfile().modifiedAt <= marker.deletedAt {
                try applyRemoteDeletion(marker)
                return
            }
            var local = getLocalProfile()
            local.modifiedAt = nextRevision(after: state)
            if case .profile(let cloud) = state, cloud != local {
                try preserveForRecovery(cloud)
            }
            try saveToLocal(local)
            try await cloudSyncManager.saveProfileToCloud(local)
        } else {
            switch try await cloudSyncManager.loadProfileStateFromCloud() {
            case .missing:
                break
            case .profile(let cloud):
                let local = getLocalProfile()
                if !local.isEmpty, local != cloud {
                    try preserveForRecovery(local)
                }
                try saveToLocal(cloud)
            case .deleted(let marker):
                try applyRemoteDeletion(marker)
            }
        }
    }

    func deleteLocalProfile() throws {
        try removeLocalProfileFile()
        if let recoveryDirectoryURL, FileManager.default.fileExists(atPath: recoveryDirectoryURL.path) {
            try FileManager.default.removeItem(at: recoveryDirectoryURL)
        }
    }
}

// MARK: - Private

private extension UserProfileManager {
    func saveToLocal(_ profile: UserProfile) throws {
        guard let url = localFileURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try makeEncoder().encode(profile)
        try data.write(to: url, options: .atomic)
        let storedProfile = try makeDecoder().decode(UserProfile.self, from: Data(contentsOf: url))
        guard storedProfile == profile else { throw CloudSyncError.cloudContentChanged }
    }

    /// One-time migration from the old `userProfile_data` UserDefaults blob to the
    /// new JSON file in DocumentDirectory.
    func migrateFromUserDefaultsIfNeeded() throws {
        guard let url = localFileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        guard let data = defaults.data(forKey: Keys.legacyProfileData) else { return }
        let profile = try makeDecoder().decode(UserProfile.self, from: data)
        try saveToLocal(profile)
        defaults.removeObject(forKey: Keys.legacyProfileData)
    }

    /// One-time migration from the legacy per-key NSUbiquitousKeyValueStore / UserDefaults
    /// storage to the new single JSON file in DocumentDirectory.
    func migrateLegacyKeysIfNeeded() throws {
        guard let url = localFileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        let legacyName = defaults.string(forKey: "userProfile_name")
        let legacyDescription = defaults.string(forKey: "userProfile_description")
        let legacyExtraInfo = defaults.string(forKey: "userProfile_extraInfo")

        // Also check NSUbiquitousKeyValueStore for any data stored there.
        let cloud = NSUbiquitousKeyValueStore.default
        let cloudName = cloud.string(forKey: "userProfile_name")
        let cloudDescription = cloud.string(forKey: "userProfile_description")
        let cloudExtraInfo = cloud.string(forKey: "userProfile_extraInfo")

        let name = legacyName ?? cloudName ?? ""
        let description = legacyDescription ?? cloudDescription ?? ""
        let extraInfo = legacyExtraInfo ?? cloudExtraInfo ?? ""

        let profile = UserProfile(name: name, profileDescription: description, extraInfo: extraInfo)

        if !profile.isEmpty {
            try saveToLocal(profile)
            defaults.removeObject(forKey: "userProfile_name")
            defaults.removeObject(forKey: "userProfile_description")
            defaults.removeObject(forKey: "userProfile_extraInfo")
            cloud.removeObject(forKey: "userProfile_name")
            cloud.removeObject(forKey: "userProfile_description")
            cloud.removeObject(forKey: "userProfile_extraInfo")
            cloud.synchronize()
        }
    }

    func reconcileBeforeSaving(_ local: UserProfile, with state: CloudUserProfileState) throws {
        switch state {
        case .missing:
            break
        case .deleted(let marker):
            guard local.modifiedAt > marker.deletedAt else {
                if !local.isEmpty { try preserveForRecovery(local) }
                try removeLocalProfileFile()
                throw CloudSyncError.staleProfileRevision
            }
        case .profile(let cloud):
            if cloud.modifiedAt > local.modifiedAt {
                if !local.isEmpty { try preserveForRecovery(local) }
                try saveToLocal(cloud)
                throw CloudSyncError.staleProfileRevision
            }
            if cloud.modifiedAt == local.modifiedAt, cloud != local {
                throw CloudSyncError.conflictingProfileRevision
            }
            if cloud != local {
                try preserveForRecovery(cloud)
            }
        }
    }

    func applyRemoteDeletion(_ marker: CloudDeletionMarker) throws {
        let local = getLocalProfile()
        guard local.modifiedAt <= marker.deletedAt else { return }
        if !local.isEmpty { try preserveForRecovery(local) }
        try removeLocalProfileFile()
    }

    func removeLocalProfileFile() throws {
        guard let localFileURL, FileManager.default.fileExists(atPath: localFileURL.path) else { return }
        try FileManager.default.removeItem(at: localFileURL)
    }

    func preserveForRecovery(_ profile: UserProfile) throws {
        guard let recoveryDirectoryURL else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: recoveryDirectoryURL, withIntermediateDirectories: true)
        let data = try makeEncoder().encode(profile)
        let url = recoveryDirectoryURL.appendingPathComponent("\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
        let recovered = try makeDecoder().decode(UserProfile.self, from: Data(contentsOf: url))
        guard recovered == profile else { throw CloudSyncError.cloudContentChanged }
    }

    func nextRevision(after state: CloudUserProfileState) -> Date {
        let remoteRevision: Date
        switch state {
        case .missing:
            remoteRevision = .distantPast
        case .profile(let profile):
            remoteRevision = profile.modifiedAt
        case .deleted(let marker):
            remoteRevision = marker.deletedAt
        }
        return max(Date(), remoteRevision.addingTimeInterval(0.001))
    }

    func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - iCloud file monitoring

    func startMonitoringCloudFile() {
        guard settingsManager.getIsCloudSyncEnabled() else { return }
        Task { [weak self] in
            guard let self, await cloudSyncManager.checkCloudAvailability() else { return }
            beginMonitoringCloudFile()
        }
    }

    func beginMonitoringCloudFile() {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(
            format: "%K IN %@",
            NSMetadataItemFSNameKey,
            ["UserProfile.json", "UserProfileDeletion.json"]
        )
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        queryObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            // queue: .main guarantees main-thread execution.
            MainActor.assumeIsolated {
                guard let self, self.settingsManager.getIsCloudSyncEnabled() else { return }
                Task {
                    do {
                        _ = try await self.getCloudProfileState()
                        NotificationCenter.default.post(
                            name: UserProfileManager.profileDidChangeExternallyNotification,
                            object: nil
                        )
                    } catch {
                        LogManager.error("External user profile reconciliation failed.")
                    }
                }
            }
        }

        metadataQuery = query
        query.start()
    }
}
