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
    func getLastSuccessfulCloudSyncDate() -> Date?
    func setLastSuccessfulCloudSyncDate(_ value: Date)
    func getAcceptedCloudAccountFingerprint() -> String?
    func setAcceptedCloudAccountFingerprint(_ value: String)
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
    func getAvailableSearchTools() -> [SearchToolItem]
    func setAvailableSearchTools(_ tools: [SearchToolItem])
    func getIsPrivacyScreenEnabled() -> Bool
    func setIsPrivacyScreenEnabled(_ value: Bool)
    func getHasEnoughConversationsForMemoryTip() -> Bool
    func setHasEnoughConversationsForMemoryTip(_ value: Bool)
    func getEnabledMCPToolIds() -> [String]
    func setEnabledMCPToolIds(_ ids: [String])
    func getDismissedRemoteBannerKey() -> String?
    func setDismissedRemoteBannerKey(_ value: String?)
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
        static let lastSuccessfulCloudSyncDate = "lastSuccessfulCloudSyncDate"
        static let acceptedCloudAccountFingerprint = "acceptedCloudAccountFingerprint"
        static let showTokenUsage = "showTokenUsage"
        static let isWebSearchEnabled = "isWebSearchEnabled"
        static let selectedTTSModelId = "selectedTTSModelId"
        static let selectedSTTModelId = "selectedSTTModelId"
        static let webSearchToolName = "webSearchToolName"
        static let webSearchMaxResults = "webSearchMaxResults"
        static let availableSearchTools = "availableSearchTools"
        static let isPrivacyScreenEnabled = "isPrivacyScreenEnabled"
        static let hasEnoughConversationsForMemoryTip = "hasEnoughConversationsForMemoryTip"
        static let enabledMCPToolIds = "enabledMCPToolIds"
        static let dismissedRemoteBannerKey = "dismissedRemoteBannerKey"

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
        guard defaults.bool(forKey: Keys.isCloudSyncEnabled) != value else { return }
        defaults.set(value, forKey: Keys.isCloudSyncEnabled)
        NotificationCenter.default.post(name: .cloudSyncIntentDidChange, object: nil)
    }

    func getLastSuccessfulCloudSyncDate() -> Date? {
        defaults.object(forKey: Keys.lastSuccessfulCloudSyncDate) as? Date
    }

    func setLastSuccessfulCloudSyncDate(_ value: Date) {
        defaults.set(value, forKey: Keys.lastSuccessfulCloudSyncDate)
    }

    func getAcceptedCloudAccountFingerprint() -> String? {
        defaults.string(forKey: Keys.acceptedCloudAccountFingerprint)
    }

    func setAcceptedCloudAccountFingerprint(_ value: String) {
        let isLowercaseSHA256 = value.utf8.count == 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
        guard isLowercaseSHA256 else { return }
        defaults.set(value, forKey: Keys.acceptedCloudAccountFingerprint)
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
        defaults.string(forKey: Keys.webSearchToolName) ?? ""
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

    func getAvailableSearchTools() -> [SearchToolItem] {
        guard let data = defaults.data(forKey: Keys.availableSearchTools),
              let tools = try? JSONDecoder().decode([SearchToolItem].self, from: data) else {
            return []
        }
        return tools
    }

    func setAvailableSearchTools(_ tools: [SearchToolItem]) {
        guard let data = try? JSONEncoder().encode(tools) else { return }
        defaults.set(data, forKey: Keys.availableSearchTools)
    }

    func getIsPrivacyScreenEnabled() -> Bool {
        let stored = defaults.object(forKey: Keys.isPrivacyScreenEnabled)
        return stored == nil ? true : defaults.bool(forKey: Keys.isPrivacyScreenEnabled)
    }

    func setIsPrivacyScreenEnabled(_ value: Bool) {
        defaults.set(value, forKey: Keys.isPrivacyScreenEnabled)
    }

    func getHasEnoughConversationsForMemoryTip() -> Bool {
        defaults.bool(forKey: Keys.hasEnoughConversationsForMemoryTip)
    }

    func setHasEnoughConversationsForMemoryTip(_ value: Bool) {
        defaults.set(value, forKey: Keys.hasEnoughConversationsForMemoryTip)
    }

    func getEnabledMCPToolIds() -> [String] {
        defaults.stringArray(forKey: Keys.enabledMCPToolIds) ?? []
    }

    func setEnabledMCPToolIds(_ ids: [String]) {
        defaults.set(ids, forKey: Keys.enabledMCPToolIds)
    }

    func getDismissedRemoteBannerKey() -> String? {
        defaults.string(forKey: Keys.dismissedRemoteBannerKey)
    }

    func setDismissedRemoteBannerKey(_ value: String?) {
        defaults.set(value, forKey: Keys.dismissedRemoteBannerKey)
    }

    func deleteAll() {
        let wasCloudSyncEnabled = getIsCloudSyncEnabled()
        defaults.removeObject(forKey: Keys.isOnboardingCompleted)
        defaults.removeObject(forKey: Keys.selectedModelId)
        defaults.removeObject(forKey: Keys.isCloudSyncEnabled)
        defaults.removeObject(forKey: Keys.lastSuccessfulCloudSyncDate)
        defaults.removeObject(forKey: Keys.acceptedCloudAccountFingerprint)
        defaults.removeObject(forKey: Keys.showTokenUsage)
        defaults.removeObject(forKey: Keys.isWebSearchEnabled)
        defaults.removeObject(forKey: Keys.selectedTTSModelId)
        defaults.removeObject(forKey: Keys.selectedSTTModelId)
        defaults.removeObject(forKey: Keys.webSearchToolName)
        defaults.removeObject(forKey: Keys.webSearchMaxResults)
        defaults.removeObject(forKey: Keys.availableSearchTools)
        defaults.removeObject(forKey: Keys.isPrivacyScreenEnabled)
        defaults.removeObject(forKey: Keys.hasEnoughConversationsForMemoryTip)
        defaults.removeObject(forKey: Keys.enabledMCPToolIds)
        defaults.removeObject(forKey: Keys.dismissedRemoteBannerKey)
        defaults.removeObject(forKey: LegacyKeys.serverBaseURL)
        defaults.removeObject(forKey: LegacyKeys.apiKey)
        keychainManager.deleteAll()
        if wasCloudSyncEnabled {
            NotificationCenter.default.post(name: .cloudSyncIntentDidChange, object: nil)
        }
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
