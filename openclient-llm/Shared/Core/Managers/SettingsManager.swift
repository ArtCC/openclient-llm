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
    func getIsWebSearchEnabled() -> Bool
    func setIsWebSearchEnabled(_ value: Bool)
    func getSelectedTTSModelId() -> String?
    func setSelectedTTSModelId(_ value: String?)
    func getSelectedTTSVoice(forModelId modelId: String) -> String
    func setSelectedTTSVoice(_ voice: String, forModelId modelId: String)
    func getSelectedSTTModelId() -> String?
    func setSelectedSTTModelId(_ value: String?)
    func getWebSearchToolName() -> String
    func setWebSearchToolName(_ value: String)
    func getWebSearchMaxResults() -> Int
    func setWebSearchMaxResults(_ value: Int)
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
        static let isWebSearchEnabled = "isWebSearchEnabled"
        static let selectedTTSModelId = "selectedTTSModelId"
        static let selectedSTTModelId = "selectedSTTModelId"
        static let webSearchToolName = "webSearchToolName"
        static let webSearchMaxResults = "webSearchMaxResults"

        static func ttsVoiceKey(forModelId modelId: String) -> String {
            "tts_voice_\(modelId)"
        }
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

    func getIsWebSearchEnabled() -> Bool {
        defaults.bool(forKey: Keys.isWebSearchEnabled)
    }

    func setIsWebSearchEnabled(_ value: Bool) {
        defaults.set(value, forKey: Keys.isWebSearchEnabled)
    }

    func getSelectedTTSModelId() -> String? {
        defaults.string(forKey: Keys.selectedTTSModelId)
    }

    func setSelectedTTSModelId(_ value: String?) {
        defaults.set(value, forKey: Keys.selectedTTSModelId)
    }

    func getSelectedTTSVoice(forModelId modelId: String) -> String {
        defaults.string(forKey: Keys.ttsVoiceKey(forModelId: modelId)) ?? TTSVoice.alloy.rawValue
    }

    func setSelectedTTSVoice(_ voice: String, forModelId modelId: String) {
        defaults.set(voice, forKey: Keys.ttsVoiceKey(forModelId: modelId))
    }

    func getSelectedSTTModelId() -> String? {
        defaults.string(forKey: Keys.selectedSTTModelId)
    }

    func setSelectedSTTModelId(_ value: String?) {
        defaults.set(value, forKey: Keys.selectedSTTModelId)
    }

    func getWebSearchToolName() -> String {
        defaults.string(forKey: Keys.webSearchToolName) ?? "brave-search"
    }

    func setWebSearchToolName(_ value: String) {
        defaults.set(value, forKey: Keys.webSearchToolName)
    }

    func getWebSearchMaxResults() -> Int {
        let stored = defaults.integer(forKey: Keys.webSearchMaxResults)
        return stored > 0 ? stored : 10
    }

    func setWebSearchMaxResults(_ value: Int) {
        defaults.set(value, forKey: Keys.webSearchMaxResults)
    }

    func deleteAll() {
        defaults.removeObject(forKey: Keys.isOnboardingCompleted)
        defaults.removeObject(forKey: Keys.selectedModelId)
        defaults.removeObject(forKey: Keys.isCloudSyncEnabled)
        defaults.removeObject(forKey: Keys.showTokenUsage)
        defaults.removeObject(forKey: Keys.isWebSearchEnabled)
        defaults.removeObject(forKey: Keys.selectedTTSModelId)
        defaults.removeObject(forKey: Keys.selectedSTTModelId)
        defaults.removeObject(forKey: Keys.webSearchToolName)
        defaults.removeObject(forKey: Keys.webSearchMaxResults)
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
