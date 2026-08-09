//
//  RemoteConfig.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct RemoteConfig: Codable, Equatable, Sendable {
    struct MaintenanceMode: Codable, Equatable, Sendable {
        let enabled: Bool
    }

    struct AppUpdate: Codable, Equatable, Sendable {
        let ios: PlatformUpdate
        let macos: PlatformUpdate
    }

    struct PlatformUpdate: Codable, Equatable, Sendable {
        let enabled: Bool
        let forceUpdate: Bool
        let latestVersion: String
        let updateURL: URL
    }

    struct Banner: Codable, Equatable, Sendable {
        let active: Bool
        let dismissBannerKey: String
        let platforms: [Platform]
        let items: [String: Item]
    }

    struct Item: Codable, Equatable, Sendable {
        let title: String
        let subtitle: String
        let cta: String
        let action: Action
        let url: String
        let emoji: String
    }

    enum Platform: String, Codable, Equatable, Sendable {
        case ios
        case macos
    }

    enum Action: String, Codable, Equatable, Sendable {
        case close
        case openURL = "open_url"
    }

    let schemaVersion: Int
    let maintenanceMode: MaintenanceMode
    let appUpdate: AppUpdate
    let banner: Banner

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case maintenanceMode = "maintenance_mode"
        case appUpdate = "app_update"
        case banner
    }
}

// MARK: - Coding Keys

private extension RemoteConfig.PlatformUpdate {
    enum CodingKeys: String, CodingKey {
        case enabled
        case forceUpdate = "force_update"
        case latestVersion = "latest_version"
        case updateURL = "update_url"
    }
}

private extension RemoteConfig.Banner {
    enum CodingKeys: String, CodingKey {
        case active
        case dismissBannerKey = "dismiss_banner_key"
        case platforms
        case items
    }
}
