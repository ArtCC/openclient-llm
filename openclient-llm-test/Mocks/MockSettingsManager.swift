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

    func deleteAll() {
        isOnboardingCompleted = false
        serverBaseURL = ""
        apiKey = ""
        selectedModelId = nil
        deleteAllCalled = true
    }
}
