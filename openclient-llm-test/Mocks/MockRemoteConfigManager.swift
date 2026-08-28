//
//  MockRemoteConfigManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

@MainActor
final class MockRemoteConfigManager: RemoteConfigManagerProtocol {
    var result: Result<RemoteConfig, Error> = .success(.stub())
    var currentConfig: RemoteConfig?

    func loadConfig() async throws -> RemoteConfig {
        let config = try result.get()
        currentConfig = config
        return config
    }
}

extension RemoteConfig {
    static func stub(
        isMaintenanceEnabled: Bool = false,
        isUpdateEnabled: Bool = true,
        isForceUpdate: Bool = false,
        latestVersion: String = "1.0.0",
        banner: Banner? = nil,
        isTipJarEnabled: Bool? = true,
        showIconPacks: [String]? = nil
    ) -> RemoteConfig {
        let update = PlatformUpdate(
            enabled: isUpdateEnabled,
            forceUpdate: isForceUpdate,
            latestVersion: latestVersion,
            updateURL: URL(filePath: "/update")
        )
        return RemoteConfig(
            schemaVersion: 1,
            maintenanceMode: .init(enabled: isMaintenanceEnabled),
            appUpdate: .init(ios: update, macos: update),
            banner: banner ?? .init(active: false, dismissBannerKey: "test", platforms: [], items: [:]),
            settingsSection: makeSettingsSection(
                isTipJarEnabled: isTipJarEnabled,
                showIconPacks: showIconPacks
            )
        )
    }

    private static func makeSettingsSection(
        isTipJarEnabled: Bool?,
        showIconPacks: [String]?
    ) -> SettingsSection? {
        guard isTipJarEnabled != nil || showIconPacks != nil else { return nil }
        return SettingsSection(
            tipOption: isTipJarEnabled ?? true,
            showIconPacks: showIconPacks
        )
    }
}
