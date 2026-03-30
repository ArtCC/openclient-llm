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
}

// Safety: UserDefaults is thread-safe per Apple documentation.
// All stored properties are immutable (`let`).
final class SettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let isOnboardingCompleted = "isOnboardingCompleted"
        static let serverBaseURL = "serverBaseURL"
        // TODO: Migrate API key storage to KeychainManager for production security
        static let apiKey = "apiKey"
        static let selectedModelId = "selectedModelId"
    }

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public

    func getIsOnboardingCompleted() -> Bool {
        defaults.bool(forKey: Keys.isOnboardingCompleted)
    }

    func setIsOnboardingCompleted(_ value: Bool) {
        defaults.set(value, forKey: Keys.isOnboardingCompleted)
    }

    func getServerBaseURL() -> String {
        defaults.string(forKey: Keys.serverBaseURL) ?? ""
    }

    func setServerBaseURL(_ value: String) {
        defaults.set(value, forKey: Keys.serverBaseURL)
    }

    func getAPIKey() -> String {
        defaults.string(forKey: Keys.apiKey) ?? ""
    }

    func setAPIKey(_ value: String) {
        defaults.set(value, forKey: Keys.apiKey)
    }

    func getSelectedModelId() -> String? {
        defaults.string(forKey: Keys.selectedModelId)
    }

    func setSelectedModelId(_ value: String?) {
        defaults.set(value, forKey: Keys.selectedModelId)
    }
}
