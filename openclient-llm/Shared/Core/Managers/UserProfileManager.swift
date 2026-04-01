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
}

// Safety: NSUbiquitousKeyValueStore and UserDefaults are thread-safe per Apple documentation.
// All stored properties are immutable (`let`).
final class UserProfileManager: UserProfileManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let name = "userProfile_name"
        static let profileDescription = "userProfile_description"
        static let extraInfo = "userProfile_extraInfo"
    }

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        setupCloudObserver()
    }

    // MARK: - Public

    func getProfile() -> UserProfile {
        UserProfile(
            name: store.string(forKey: Keys.name) ?? "",
            profileDescription: store.string(forKey: Keys.profileDescription) ?? "",
            extraInfo: store.string(forKey: Keys.extraInfo) ?? ""
        )
    }

    func saveProfile(_ profile: UserProfile) {
        store.set(profile.name, forKey: Keys.name)
        store.set(profile.profileDescription, forKey: Keys.profileDescription)
        store.set(profile.extraInfo, forKey: Keys.extraInfo)
        cloudStore?.synchronize()
    }
}

// MARK: - Private

private extension UserProfileManager {
    var cloudStore: NSUbiquitousKeyValueStore? {
        NSUbiquitousKeyValueStore.isCloudAvailable ? NSUbiquitousKeyValueStore.default : nil
    }

    /// Returns the iCloud KV store when available, falling back to UserDefaults.
    var store: KeyValueStore {
        if let cloud = cloudStore {
            return CloudKeyValueStore(cloud)
        }
        return defaults
    }

    func setupCloudObserver() {
        guard cloudStore != nil else { return }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            guard let changedKeys = notification.userInfo?[
                NSUbiquitousKeyValueStoreChangedKeysKey
            ] as? [String],
                  changedKeys.contains(where: { $0.hasPrefix("userProfile_") }) else { return }
            // Mirror cloud values into UserDefaults so they survive iCloud sign-out.
            // queue: .main guarantees main-thread execution; assumeIsolated makes that explicit.
            MainActor.assumeIsolated { [weak self] in
                guard let self else { return }
                let cloud = NSUbiquitousKeyValueStore.default
                self.defaults.set(cloud.string(forKey: Keys.name), forKey: Keys.name)
                self.defaults.set(cloud.string(forKey: Keys.profileDescription), forKey: Keys.profileDescription)
                self.defaults.set(cloud.string(forKey: Keys.extraInfo), forKey: Keys.extraInfo)
            }
        }
    }
}

// MARK: - KeyValueStore

private protocol KeyValueStore {
    func string(forKey key: String) -> String?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyValueStore {}

private struct CloudKeyValueStore: KeyValueStore {
    private let store: NSUbiquitousKeyValueStore

    init(_ store: NSUbiquitousKeyValueStore) {
        self.store = store
    }

    func string(forKey key: String) -> String? {
        store.string(forKey: key)
    }

    func set(_ value: Any?, forKey key: String) {
        if let str = value as? String {
            store.set(str, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
        // Mirror to UserDefaults as fallback.
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - NSUbiquitousKeyValueStore availability

private extension NSUbiquitousKeyValueStore {
    static var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
