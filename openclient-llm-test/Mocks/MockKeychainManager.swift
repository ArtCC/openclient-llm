//
//  MockKeychainManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockKeychainManager: KeychainManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var serverBaseURL: String = ""
    var apiKey: String = ""
    var deleteAllCalled: Bool = false

    // MARK: - Public

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

    func deleteAll() {
        serverBaseURL = ""
        apiKey = ""
        deleteAllCalled = true
    }
}
