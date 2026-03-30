//
//  KeychainManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol KeychainManagerProtocol: Sendable {
    func getServerBaseURL() -> String
    func setServerBaseURL(_ value: String)
    func getAPIKey() -> String
    func setAPIKey(_ value: String)
    func deleteAll()
}

// Safety: All Keychain operations use thread-safe Security framework APIs.
// All stored properties are immutable (`let`).
final class KeychainManager: KeychainManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let serverBaseURL = "com.openclient-llm.serverBaseURL"
        static let apiKey = "com.openclient-llm.apiKey"
    }

    private let service: String

    // MARK: - Init

    init(service: String = "com.openclient-llm") {
        self.service = service
    }

    // MARK: - Public

    func getServerBaseURL() -> String {
        getString(forKey: Keys.serverBaseURL) ?? ""
    }

    func setServerBaseURL(_ value: String) {
        setString(value, forKey: Keys.serverBaseURL)
    }

    func getAPIKey() -> String {
        getString(forKey: Keys.apiKey) ?? ""
    }

    func setAPIKey(_ value: String) {
        setString(value, forKey: Keys.apiKey)
    }

    func deleteAll() {
        deleteItem(forKey: Keys.serverBaseURL)
        deleteItem(forKey: Keys.apiKey)
    }
}

// MARK: - Private

private extension KeychainManager {
    func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func setString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        deleteItem(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    func deleteItem(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
