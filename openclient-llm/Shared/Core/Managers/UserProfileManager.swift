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
    func saveProfile(_ profile: UserProfile)
    func getLocalProfile() -> UserProfile
    func getCloudProfile() -> UserProfile?
    func resolveCloudSyncConflict(keepLocal: Bool)
    func deleteLocalProfile()
}

/// Manages the user's personal context with optional iCloud file-based sync.
///
/// When iCloud sync is enabled the cloud `UserProfile.json` is the single source of truth.
/// Local storage is a JSON file in DocumentDirectory and is used when sync is disabled.
///
/// Safety: FileManager operations are thread-safe for different paths. CloudSyncManager
/// operations are file-based and called synchronously. The NSMetadataQuery is
/// created and stopped on the main thread; the class is not Sendable-safe for
/// mutable fields but those are only touched during init/deinit on main.
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
    private nonisolated(unsafe) var metadataQuery: NSMetadataQuery?
    // Must be stored to keep the observer alive.
    private nonisolated(unsafe) var queryObserver: NSObjectProtocol?

    private var localFileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.fileName)
    }

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager()
    ) {
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        migrateFromUserDefaultsIfNeeded()
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
        if settingsManager.getIsCloudSyncEnabled() {
            if let cloud = try? cloudSyncManager.loadProfileFromCloud() {
                // Keep local cache up to date.
                saveToLocal(cloud)
                return cloud
            }
        }
        return getLocalProfile()
    }

    func saveProfile(_ profile: UserProfile) {
        saveToLocal(profile)
        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.saveProfileToCloud(profile)
        }
    }

    func getLocalProfile() -> UserProfile {
        guard let url = localFileURL,
              let data = try? Data(contentsOf: url),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return migrateLegacyKeysIfNeeded()
        }
        return profile
    }

    func getCloudProfile() -> UserProfile? {
        try? cloudSyncManager.loadProfileFromCloud()
    }

    func resolveCloudSyncConflict(keepLocal: Bool) {
        if keepLocal {
            let local = getLocalProfile()
            try? cloudSyncManager.saveProfileToCloud(local)
        } else {
            if let cloud = try? cloudSyncManager.loadProfileFromCloud() {
                saveToLocal(cloud)
            }
        }
    }

    func deleteLocalProfile() {
        guard let url = localFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Private

private extension UserProfileManager {
    func saveToLocal(_ profile: UserProfile) {
        guard let url = localFileURL,
              let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// One-time migration from the old `userProfile_data` UserDefaults blob to the
    /// new JSON file in DocumentDirectory.
    func migrateFromUserDefaultsIfNeeded() {
        guard let url = localFileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.legacyProfileData),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            saveToLocal(profile)
            defaults.removeObject(forKey: Keys.legacyProfileData)
        }
    }

    /// One-time migration from the legacy per-key NSUbiquitousKeyValueStore / UserDefaults
    /// storage to the new single JSON file in DocumentDirectory.
    func migrateLegacyKeysIfNeeded() -> UserProfile {
        let legacyDefaults = UserDefaults.standard
        let legacyName = legacyDefaults.string(forKey: "userProfile_name")
        let legacyDescription = legacyDefaults.string(forKey: "userProfile_description")
        let legacyExtraInfo = legacyDefaults.string(forKey: "userProfile_extraInfo")

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
            saveToLocal(profile)
            // Clean up legacy keys.
            legacyDefaults.removeObject(forKey: "userProfile_name")
            legacyDefaults.removeObject(forKey: "userProfile_description")
            legacyDefaults.removeObject(forKey: "userProfile_extraInfo")
            cloud.removeObject(forKey: "userProfile_name")
            cloud.removeObject(forKey: "userProfile_description")
            cloud.removeObject(forKey: "userProfile_extraInfo")
            cloud.synchronize()

            // If cloud sync is enabled, push the migrated profile to the new file-based store.
            if settingsManager.getIsCloudSyncEnabled() {
                try? cloudSyncManager.saveProfileToCloud(profile)
            }
        }

        return profile
    }

    // MARK: - iCloud file monitoring

    func startMonitoringCloudFile() {
        guard cloudSyncManager.isCloudAvailable() else { return }

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, "UserProfile.json")
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        let settingsManager = self.settingsManager
        queryObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { _ in
            // queue: .main guarantees main-thread execution.
            MainActor.assumeIsolated {
                guard settingsManager.getIsCloudSyncEnabled() else { return }
                NotificationCenter.default.post(
                    name: UserProfileManager.profileDidChangeExternallyNotification,
                    object: nil
                )
            }
        }

        metadataQuery = query
        query.start()
    }
}
