//
//  SettingsManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//

import Foundation

protocol SettingsManagerProtocol: Sendable {
    var isOnboardingCompleted: Bool { get set }
    var serverBaseURL: String { get set }
}

final class SettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let isOnboardingCompleted = "isOnboardingCompleted"
        static let serverBaseURL = "serverBaseURL"
    }

    private let defaults: UserDefaults

    var isOnboardingCompleted: Bool {
        get { defaults.bool(forKey: Keys.isOnboardingCompleted) }
        set { defaults.set(newValue, forKey: Keys.isOnboardingCompleted) }
    }

    var serverBaseURL: String {
        get { defaults.string(forKey: Keys.serverBaseURL) ?? "" }
        set { defaults.set(newValue, forKey: Keys.serverBaseURL) }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}
