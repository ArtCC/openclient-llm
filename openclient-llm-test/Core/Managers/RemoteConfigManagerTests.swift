//
//  RemoteConfigManagerTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class RemoteConfigManagerTests: XCTestCase {
    // MARK: - Properties

    private let endpoint = URL(string: "https://example.com/config.json")
    private var defaults: UserDefaults!
    private var suiteName: String!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        suiteName = "RemoteConfigManagerTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_loadConfig_withoutCache_downloadsAndParsesConfig() async throws {
        // Given
        let manager = RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: try makeLoader(version: "1.6.30"),
            defaults: defaults,
            refreshInterval: 6 * 60 * 60
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "1.6.30")
        XCTAssertEqual(manager.currentConfig, config)
    }

    func test_loadConfig_withFreshCache_returnsCachedConfig() async throws {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        _ = try await makeManager(version: "1.6.30", now: now, refreshInterval: .zero).loadConfig()
        let manager = try makeManager(
            version: "2.0.0",
            now: now.addingTimeInterval(60),
            refreshInterval: 6 * 60 * 60
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "1.6.30")
        XCTAssertEqual(manager.currentConfig, config)
    }

    func test_loadConfig_withExpiredCache_downloadsLatestConfig() async throws {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        _ = try await makeManager(version: "1.6.30", now: now, refreshInterval: .zero).loadConfig()
        let manager = try makeManager(
            version: "2.0.0",
            now: now.addingTimeInterval((6 * 60 * 60) + 1),
            refreshInterval: 6 * 60 * 60
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "2.0.0")
    }

    func test_loadConfig_whenRefreshFails_returnsCachedConfig() async throws {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        _ = try await makeManager(version: "1.6.30", now: now, refreshInterval: .zero).loadConfig()
        let manager = RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: { _ in throw URLError(.notConnectedToInternet) },
            defaults: defaults,
            refreshInterval: .zero,
            now: { now }
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "1.6.30")
    }

    func test_loadConfig_tipJarDisabled_returnsDisabledFlag() async throws {
        // Given
        let manager = RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: try makeLoader(version: "1.6.30", tipJarEnabled: false),
            defaults: defaults,
            refreshInterval: .zero
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertFalse(config.isTipJarEnabled)
    }

    func test_loadConfig_tipJarMissing_defaultsToEnabled() async throws {
        // Given
        let manager = RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: try makeLoader(version: "1.6.30", tipJarEnabled: nil),
            defaults: defaults,
            refreshInterval: .zero
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertTrue(config.isTipJarEnabled)
    }
}

// MARK: - Private

private extension RemoteConfigManagerTests {
    func makeManager(
        version: String,
        now: Date,
        refreshInterval: TimeInterval
    ) throws -> RemoteConfigManager {
        RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: try makeLoader(version: version),
            defaults: defaults,
            refreshInterval: refreshInterval,
            now: { now }
        )
    }

    func makeLoader(
        version: String,
        tipJarEnabled: Bool? = true
    ) throws -> RemoteConfigDataLoader {
        let endpoint = try XCTUnwrap(endpoint)
        let response = try XCTUnwrap(
            HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)
        )
        let data = Data(configJSON(version: version, tipJarEnabled: tipJarEnabled).utf8)
        return { _ in (data, response) }
    }

    func configJSON(version: String, tipJarEnabled: Bool?) -> String {
        let tipJar = tipJarEnabled.map {
            """
              "settings_section": { "tip_option": \($0) },
            """
        } ?? ""
        return """
        {
          "schema_version": 1,
        \(tipJar)
          "maintenance_mode": { "enabled": false },
          "app_update": {
            "ios": {
              "enabled": true,
              "force_update": false,
              "latest_version": "\(version)",
              "update_url": "https://apps.apple.com/app/id6761379499"
            },
            "macos": {
              "enabled": true,
              "force_update": false,
              "latest_version": "\(version)",
              "update_url": "https://apps.apple.com/app/id6761379499"
            }
          },
          "banner": {
            "active": false,
            "dismiss_banner_key": "test-banner",
            "platforms": ["ios", "macos"],
            "items": {
              "en": {
                "title": "Title",
                "subtitle": "Subtitle",
                "cta": "Close",
                "action": "close",
                "url": "",
                "emoji": ""
              }
            }
          }
        }
        """
    }
}
