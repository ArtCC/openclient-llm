//
//  MockSettingsManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var isOnboardingCompleted: Bool = false
    var serverBaseURL: String = ""
    var apiKey: String = ""
    var selectedModelId: String?
    var selectedTTSModelId: String?
    var ttsVoices: [String: String] = [:]
    var isCloudSyncEnabled: Bool = false
    var showTokenUsage: Bool = true
    var deleteAllCalled: Bool = false

    // MARK: - Public

    func getIsOnboardingCompleted() -> Bool {
        isOnboardingCompleted
    }

    func setIsOnboardingCompleted(_ value: Bool) {
        isOnboardingCompleted = value
    }

    func getServerBaseURL() -> String {
        serverBaseURL
    }

    func setServerBaseURL(_ value: String) {
        serverBaseURL = value
    }

    func getAPIKey() -> String {
        apiKey
    }

    func setAPIKey(_ value: String) {
        apiKey = value
    }

    func getSelectedModelId() -> String? {
        selectedModelId
    }

    func setSelectedModelId(_ value: String?) {
        selectedModelId = value
    }

    func getIsCloudSyncEnabled() -> Bool {
        isCloudSyncEnabled
    }

    func setIsCloudSyncEnabled(_ value: Bool) {
        isCloudSyncEnabled = value
    }

    func getShowTokenUsage() -> Bool {
        showTokenUsage
    }

    func setShowTokenUsage(_ value: Bool) {
        showTokenUsage = value
    }

    func getSelectedTTSModelId() -> String? {
        selectedTTSModelId
    }

    func setSelectedTTSModelId(_ value: String?) {
        selectedTTSModelId = value
    }

    func getSelectedTTSVoice(forModelId modelId: String) -> String {
        ttsVoices[modelId] ?? TTSVoice.alloy.rawValue
    }

    func setSelectedTTSVoice(_ voice: String, forModelId modelId: String) {
        ttsVoices[modelId] = voice
    }

    func deleteAll() {
        isOnboardingCompleted = false
        serverBaseURL = ""
        apiKey = ""
        selectedModelId = nil
        selectedTTSModelId = nil
        ttsVoices = [:]
        deleteAllCalled = true
    }
}
