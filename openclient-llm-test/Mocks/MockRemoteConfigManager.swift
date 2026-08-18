//
//  MockRemoteConfigManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockRemoteConfigManager: RemoteConfigManagerProtocol, @unchecked Sendable {
    var result: Result<RemoteConfig, Error> = .success(.stub())

    func loadConfig() async throws -> RemoteConfig {
        try result.get()
    }
}

extension RemoteConfig {
    static func stub(
        isMaintenanceEnabled: Bool = false,
        isUpdateEnabled: Bool = true,
        isForceUpdate: Bool = false,
        latestVersion: String = "1.6.25",
        banner: Banner? = nil
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
            banner: banner ?? .init(active: false, dismissBannerKey: "test", platforms: [], items: [:])
        )
    }
}
