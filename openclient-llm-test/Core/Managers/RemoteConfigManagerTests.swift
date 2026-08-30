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
            dataLoader: try makeLoader(version: "1.0.0"),
            defaults: defaults,
            refreshInterval: 6 * 60 * 60
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "1.0.0")
        XCTAssertEqual(manager.currentConfig, config)
    }

    func test_loadConfig_withFreshCache_returnsCachedConfig() async throws {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        _ = try await makeManager(version: "1.0.0", now: now, refreshInterval: .zero).loadConfig()
        let manager = try makeManager(
            version: "1.1.0",
            now: now.addingTimeInterval(60),
            refreshInterval: 6 * 60 * 60
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "1.0.0")
        XCTAssertEqual(manager.currentConfig, config)
    }

    func test_loadConfig_withExpiredCache_downloadsLatestConfig() async throws {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        _ = try await makeManager(version: "1.0.0", now: now, refreshInterval: .zero).loadConfig()
        let manager = try makeManager(
            version: "1.1.0",
            now: now.addingTimeInterval((6 * 60 * 60) + 1),
            refreshInterval: 6 * 60 * 60
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "1.1.0")
    }

    func test_loadConfig_whenRefreshFails_returnsCachedConfig() async throws {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        _ = try await makeManager(version: "1.0.0", now: now, refreshInterval: .zero).loadConfig()
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
        XCTAssertEqual(config.appUpdate.ios.latestVersion, "1.0.0")
    }

    func test_loadConfig_tipJarDisabled_returnsDisabledFlag() async throws {
        // Given
        let manager = RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: try makeLoader(version: "1.0.0", tipJarEnabled: false),
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
            dataLoader: try makeLoader(version: "1.0.0", tipJarEnabled: nil),
            defaults: defaults,
            refreshInterval: .zero
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertTrue(config.isTipJarEnabled)
    }

    func test_loadConfig_showIconPacksConfigured_returnsIdentifiers() async throws {
        // Given
        let manager = RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: try makeLoader(
                version: "1.0.0",
                showIconPacks: ["colors", "christmas"]
            ),
            defaults: defaults,
            refreshInterval: .zero
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertEqual(config.showIconPacks, ["colors", "christmas"])
    }

    func test_loadConfig_showIconPacksMissing_returnsNil() async throws {
        // Given
        let manager = RemoteConfigManager(
            endpoint: endpoint,
            dataLoader: try makeLoader(version: "1.0.0", showIconPacks: nil),
            defaults: defaults,
            refreshInterval: .zero
        )

        // When
        let config = try await manager.loadConfig()

        // Then
        XCTAssertNil(config.showIconPacks)
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
        tipJarEnabled: Bool? = true,
        showIconPacks: [String]? = nil
    ) throws -> RemoteConfigDataLoader {
        let endpoint = try XCTUnwrap(endpoint)
        let response = try XCTUnwrap(
            HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil)
        )
        let data = Data(
            configJSON(
                version: version,
                tipJarEnabled: tipJarEnabled,
                showIconPacks: showIconPacks
            ).utf8
        )
        return { _ in (data, response) }
    }

    func configJSON(
        version: String,
        tipJarEnabled: Bool?,
        showIconPacks: [String]?
    ) -> String {
        let settingsSection = settingsSectionJSON(
            tipJarEnabled: tipJarEnabled,
            showIconPacks: showIconPacks
        )
        return """
        {
          "schema_version": 1,
        \(settingsSection)
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

    func settingsSectionJSON(tipJarEnabled: Bool?, showIconPacks: [String]?) -> String {
        guard tipJarEnabled != nil || showIconPacks != nil else { return "" }
        let packValues = showIconPacks?.map { "\"\($0)\"" }.joined(separator: ", ")
        let packs = packValues.map { ", \"show_icon_packs\": [\($0)]" } ?? ""
        return """
          "settings_section": { "tip_option": \(tipJarEnabled ?? true)\(packs) },
        """
    }
}
