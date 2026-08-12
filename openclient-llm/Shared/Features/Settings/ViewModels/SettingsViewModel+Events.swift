//
//  SettingsViewModel+Events.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension SettingsViewModel {
    // MARK: - Input

    func send(_ event: Event) {
        switch event {
        case .cloudSyncToggled, .cloudSyncConflictResolved, .cloudSyncConflictCancelled,
             .syncNowTapped, .cloudSyncRetryTapped, .cloudAccountReviewConfirmed,
             .cloudAccountReviewCancelled, .cloudAccountReviewDismissed:
            handleCloudSyncEvent(event)
        case .showTokenUsageToggled, .privacyScreenToggled:
            handlePreferenceToggleEvent(event)
        case .webSearchToolNameChanged, .webSearchMaxResultsChanged, .fetchSearchToolsTapped,
             .fetchMCPToolsTapped, .mcpToolToggled:
            handleServerDiscoveryEvent(event)
        default:
            handleCoreEvent(event)
        }
    }

    // MARK: - Private

    private func handleCoreEvent(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadSettings()
        case .serverURLChanged(let url):
            updateServerURL(url)
        case .apiKeyChanged(let key):
            updateAPIKey(key)
        case .testConnectionTapped:
            testConnection()
        case .saveTapped:
            saveSettings()
        case .cloudAvailabilityRefresh:
            refreshCloudAvailability()
        case .resetConfirmed:
            resetApp()
        case .requestNotificationPermissionTapped, .notificationStatusRefresh:
            handleNotificationEvent(event)
        default:
            break
        }
    }

    private func requestNotificationPermission() {
        Task {
            await notificationPermissionUseCase.execute()
            refreshNotificationStatus()
        }
    }

    private func handleNotificationEvent(_ event: Event) {
        switch event {
        case .requestNotificationPermissionTapped:
            requestNotificationPermission()
        case .notificationStatusRefresh:
            refreshNotificationStatus()
        default:
            break
        }
    }

    private func handleServerDiscoveryEvent(_ event: Event) {
        handleWebSearchEvent(event)
        handleMCPEvent(event)
    }

    private func handleMCPEvent(_ event: Event) {
        switch event {
        case .fetchMCPToolsTapped:
            fetchMCPTools()
        case .mcpToolToggled(let toolId, let enabled):
            toggleMCPTool(toolId: toolId, enabled: enabled)
        default:
            break
        }
    }

    func enabledMCPToolIds(savedIds: [String], tools: [MCPToolInfo]) -> Set<String> {
        let currentIds = Set(tools.map(\.id))
        let legacyIds = Dictionary(uniqueKeysWithValues: tools.map { ($0.prefixedName, $0.id) })
        return Set(savedIds.compactMap { currentIds.contains($0) ? $0 : legacyIds[$0] })
    }
}
