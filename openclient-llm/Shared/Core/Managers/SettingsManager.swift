//
//  SettingsManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SettingsManagerProtocol: Sendable {
    func getIsOnboardingCompleted() -> Bool
    func setIsOnboardingCompleted(_ value: Bool)
    func getServerBaseURL() -> String
    func setServerBaseURL(_ value: String)
    func getAPIKey() -> String
    func setAPIKey(_ value: String)
    func getSelectedModelId() -> String?
    func setSelectedModelId(_ value: String?)
    func getIsCloudSyncEnabled() -> Bool
    func setIsCloudSyncEnabled(_ value: Bool)
    func getShowTokenUsage() -> Bool
    func setShowTokenUsage(_ value: Bool)
    func deleteAll()
}

// Safety: UserDefaults is thread-safe per Apple documentation.
// All stored properties are immutable (`let`).
final class SettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let isOnboardingCompleted = "isOnboardingCompleted"
        static let selectedModelId = "selectedModelId"
        static let isCloudSyncEnabled = "isCloudSyncEnabled"
        static let showTokenUsage = "showTokenUsage"
    }

    private enum LegacyKeys {
        static let serverBaseURL = "serverBaseURL"
        static let apiKey = "apiKey"
    }

    private let defaults: UserDefaults
    private let keychainManager: KeychainManagerProtocol

    // MARK: - Init

    init(
        defaults: UserDefaults = .standard,
        keychainManager: KeychainManagerProtocol = KeychainManager()
    ) {
        self.defaults = defaults
        self.keychainManager = keychainManager

        migrateToKeychain()
    }

    // MARK: - Public

    func getIsOnboardingCompleted() -> Bool {
        defaults.bool(forKey: Keys.isOnboardingCompleted)
    }

    func setIsOnboardingCompleted(_ value: Bool) {
        defaults.set(value, forKey: Keys.isOnboardingCompleted)
    }

    func getServerBaseURL() -> String {
        keychainManager.getServerBaseURL()
    }

    func setServerBaseURL(_ value: String) {
        keychainManager.setServerBaseURL(value)
    }

    func getAPIKey() -> String {
        keychainManager.getAPIKey()
    }

    func setAPIKey(_ value: String) {
        keychainManager.setAPIKey(value)
    }

    func getSelectedModelId() -> String? {
        defaults.string(forKey: Keys.selectedModelId)
    }

    func setSelectedModelId(_ value: String?) {
        defaults.set(value, forKey: Keys.selectedModelId)
    }

    func getIsCloudSyncEnabled() -> Bool {
        defaults.bool(forKey: Keys.isCloudSyncEnabled)
    }

    func setIsCloudSyncEnabled(_ value: Bool) {
        defaults.set(value, forKey: Keys.isCloudSyncEnabled)
    }

    func getShowTokenUsage() -> Bool {
        defaults.object(forKey: Keys.showTokenUsage) == nil ? true : defaults.bool(forKey: Keys.showTokenUsage)
    }

    func setShowTokenUsage(_ value: Bool) {
        defaults.set(value, forKey: Keys.showTokenUsage)
    }

    func deleteAll() {
        defaults.removeObject(forKey: Keys.isOnboardingCompleted)
        defaults.removeObject(forKey: Keys.selectedModelId)
        defaults.removeObject(forKey: Keys.isCloudSyncEnabled)
        defaults.removeObject(forKey: Keys.showTokenUsage)
        defaults.removeObject(forKey: LegacyKeys.serverBaseURL)
        defaults.removeObject(forKey: LegacyKeys.apiKey)
        keychainManager.deleteAll()
    }
}

// MARK: - Private

private extension SettingsManager {
    func migrateToKeychain() {
        if let legacyURL = defaults.string(forKey: LegacyKeys.serverBaseURL) {
            keychainManager.setServerBaseURL(legacyURL)
            defaults.removeObject(forKey: LegacyKeys.serverBaseURL)
        }

        if let legacyKey = defaults.string(forKey: LegacyKeys.apiKey) {
            keychainManager.setAPIKey(legacyKey)
            defaults.removeObject(forKey: LegacyKeys.apiKey)
        }
    }
}
