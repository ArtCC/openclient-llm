//
//  SettingsViewModel+MCP.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension SettingsViewModel {
    func fetchMCPTools(replacingCurrent: Bool = false) {
        guard case .loaded(let loadedState) = state else { return }
        guard !loadedState.isLoadingMCPTools || replacingCurrent else { return }
        mcpDiscoveryTask?.cancel()
        mcpDiscoveryGeneration += 1
        let generation = mcpDiscoveryGeneration
        let discoveryScope = settingsManager.getMCPAuthorizationScope()
        guard !discoveryScope.isEmpty else {
            var update = loadedState
            mcpDiscoveryTask = nil
            clearMCPTools(scope: discoveryScope, in: &update)
            update.isLoadingMCPTools = false
            update.mcpToolsError = String(localized: "MCP permissions require access to secure storage.")
            state = .loaded(update)
            return
        }
        observedMCPAuthorizationScope = discoveryScope
        let discoveryRevision = settingsManager.beginMCPToolDiscovery()
        var update = loadedState
        if update.mcpDiscoveryScope != discoveryScope {
            clearMCPTools(scope: discoveryScope, in: &update)
        }
        update.isLoadingMCPTools = true
        update.mcpToolsError = nil
        state = .loaded(update)
        let fetchUseCase = fetchMCPToolsUseCase
        mcpDiscoveryTask = Task { [weak self] in
            let result = await fetchUseCase.execute()
            guard let self else { return }
            defer {
                if mcpDiscoveryGeneration == generation { mcpDiscoveryTask = nil }
            }
            guard !Task.isCancelled, generation == mcpDiscoveryGeneration else { return }
            guard case .loaded(var currentState) = state else { return }
            guard discoveryScope == settingsManager.getMCPAuthorizationScope() else {
                currentState.isLoadingMCPTools = false
                state = .loaded(currentState)
                fetchMCPTools(replacingCurrent: true)
                return
            }
            let didPublishDiscovery = applyMCPDiscovery(
                result,
                scope: discoveryScope,
                discoveryRevision: discoveryRevision,
                to: &currentState
            )
            state = .loaded(currentState)
            if !didPublishDiscovery { fetchMCPTools(replacingCurrent: true) }
        }
    }

    func toggleMCPTool(toolId: String, enabled: Bool) {
        toggleMCPTools(toolIds: [toolId], enabled: enabled)
    }

    func toggleMCPTools(toolIds: [String], enabled: Bool) {
        guard case .loaded(var loadedState) = state else { return }
        let configurableIds = configurableMCPTools(toolIds: toolIds, state: loadedState).map(\.id)
        guard !configurableIds.isEmpty else { return }
        if enabled {
            loadedState.enabledMCPToolIds.formUnion(configurableIds)
        } else {
            loadedState.enabledMCPToolIds.subtract(configurableIds)
        }
        settingsManager.setEnabledMCPToolIds(Array(loadedState.enabledMCPToolIds))
        state = .loaded(loadedState)
    }

    func updateMCPToolPermission(toolId: String, permission: MCPToolPermission) {
        updateMCPToolPermissions(toolIds: [toolId], permission: permission)
    }

    func updateMCPToolPermissions(toolIds: [String], permission: MCPToolPermission) {
        guard case .loaded(var loadedState) = state else { return }
        let tools = configurableMCPTools(toolIds: toolIds, state: loadedState)
        guard !tools.isEmpty else { return }
        settingsManager.setMCPToolPermission(permission, for: tools.map(permissionKey))
        for tool in tools {
            loadedState.mcpToolPermissions[tool.id] = permission
        }
        state = .loaded(loadedState)
    }

    private func configurableMCPTools(toolIds: [String], state: LoadedState) -> [MCPToolInfo] {
        let requestedIds = Set(toolIds)
        return state.availableMCPTools.filter {
            requestedIds.contains($0.id)
                && $0.isInputSchemaSupported
                && !state.failedMCPServerIds.contains($0.serverId)
        }
    }
}

extension SettingsViewModel {
    func applyMCPDiscovery(
        _ result: MCPDiscoveryResult,
        scope: String,
        discoveryRevision: Int,
        to state: inout LoadedState
    ) -> Bool {
        let canRetainPreviousTools = state.mcpDiscoveryScope == scope
        if result.errorMessage != nil && result.servers.isEmpty {
            let didPublishFailure = settingsManager.publishMCPToolDiscoveryFailure(revision: discoveryRevision)
            guard didPublishFailure else { return false }
            state.isLoadingMCPTools = false
            state.mcpToolsError = result.errorMessage
            if canRetainPreviousTools {
                state.failedMCPServerIds = Set(state.availableMCPServers.map(\.serverId))
            } else {
                clearMCPTools(scope: scope, in: &state)
            }
            state.mcpDiscoveryRevision = discoveryRevision
            return true
        }
        let discoveredTools = result.mergingPreviouslyDiscoveredTools(
            canRetainPreviousTools ? state.availableMCPTools : []
        )
        let normalizedIds = enabledMCPToolIds(
            savedIds: settingsManager.getEnabledMCPToolIds(),
            tools: discoveredTools
        )
        let didPublishDiscovery = settingsManager.publishMCPToolDiscovery(
            revision: discoveryRevision,
            configurationKeys: mcpToolConfigurationKeys(for: result.tools),
            enabledToolIds: Array(normalizedIds),
            servers: result.servers,
            failedServerIds: result.failedServerIds
        )
        guard didPublishDiscovery else {
            state.isLoadingMCPTools = false
            return false
        }
        state.availableMCPTools = discoveredTools
        state.availableMCPServers = result.servers
        state.failedMCPServerIds = result.failedServerIds
        state.mcpDiscoveryScope = scope
        state.mcpDiscoveryRevision = discoveryRevision
        state.enabledMCPToolIds = normalizedIds
        state.mcpToolPermissions = mcpToolPermissions(for: discoveredTools)
        state.mcpToolsError = result.errorMessage
        state.isLoadingMCPTools = false
        return true
    }

    func clearMCPTools(scope: String, in state: inout LoadedState) {
        state.availableMCPTools = []
        state.availableMCPServers = []
        state.failedMCPServerIds = []
        state.enabledMCPToolIds = []
        state.mcpToolPermissions = [:]
        state.mcpDiscoveryScope = scope
        state.mcpDiscoveryRevision = 0
    }

    func mcpToolPermissions(for tools: [MCPToolInfo]) -> [String: MCPToolPermission] {
        tools.reduce(into: [String: MCPToolPermission]()) { result, tool in
            result[tool.id] = settingsManager.getMCPToolPermission(for: permissionKey(for: tool))
        }
    }

    func permissionKey(for tool: MCPToolInfo) -> String {
        tool.permissionKey(
            serverBaseURL: settingsManager.getServerBaseURL(),
            authorizationScope: settingsManager.getMCPAuthorizationScope()
        )
    }

    func mcpToolConfigurationKeys(for tools: [MCPToolInfo]) -> [String: String] {
        tools.reduce(into: [String: String]()) { result, tool in
            result[tool.id] = permissionKey(for: tool)
        }
    }

    func observeMCPToolSettingsChanges() {
        mcpSettingsObservationTask?.cancel()
        mcpSettingsObservationTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(named: .mcpToolSettingsDidChange)
            for await _ in notifications {
                guard let self else { return }
                let currentScope = settingsManager.getMCPAuthorizationScope()
                let scopeChanged = currentScope != observedMCPAuthorizationScope
                observedMCPAuthorizationScope = currentScope
                let needsRefresh = scopeChanged || mcpConfigurationNeedsRefresh()
                if needsRefresh {
                    fetchMCPTools(replacingCurrent: true)
                } else {
                    refreshMCPSettingsState()
                }
            }
        }
    }

    func refreshMCPSettingsState() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.enabledMCPToolIds = enabledMCPToolIds(
            savedIds: settingsManager.getEnabledMCPToolIds(),
            tools: loadedState.availableMCPTools
        )
        loadedState.mcpToolPermissions = mcpToolPermissions(for: loadedState.availableMCPTools)
        state = .loaded(loadedState)
    }

    func mcpConfigurationNeedsRefresh() -> Bool {
        guard case .loaded(let loadedState) = state, !loadedState.isLoadingMCPTools else { return false }
        if loadedState.mcpDiscoveryRevision < settingsManager.getPublishedMCPToolDiscoveryRevision() {
            return true
        }
        return loadedState.availableMCPTools.contains { tool in
            settingsManager.getMCPToolConfigurationKey(for: tool.id) != permissionKey(for: tool)
        }
    }
}
