//
//  MCPToolDiscoveryPublication.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct MCPToolDiscoveryPublication: Sendable {
    let configurationKeys: [String: String]
    let enabledToolIds: [String]

    static func merging(
        existingConfigurationKeys: [String: String],
        existingEnabledToolIds: [String],
        discoveredConfigurationKeys: [String: String],
        discoveredEnabledToolIds: [String],
        serverState: MCPDiscoveryServerState
    ) -> MCPToolDiscoveryPublication {
        let serversById = serverState.servers.reduce(into: [String: MCPServerInfo]()) { result, server in
            result[server.serverId] = server
        }
        let failedServerIds = serverState.failedServerIds
        var configurationKeys = existingConfigurationKeys
        var enabledToolIds = Set(existingEnabledToolIds)

        for toolId in existingConfigurationKeys.keys where shouldRemove(
            toolId: toolId,
            serversById: serversById,
            failedServerIds: failedServerIds
        ) {
            configurationKeys.removeValue(forKey: toolId)
            enabledToolIds.remove(toolId)
        }
        configurationKeys.merge(discoveredConfigurationKeys) { _, discovered in discovered }

        if failedServerIds.isEmpty {
            enabledToolIds = Set(discoveredEnabledToolIds)
        } else {
            for toolId in Array(enabledToolIds) where existingConfigurationKeys[toolId] == nil {
                guard MCPToolInfo.identity(from: toolId) != nil else { continue }
                if shouldRemove(toolId: toolId, serversById: serversById, failedServerIds: failedServerIds) {
                    enabledToolIds.remove(toolId)
                }
            }
            enabledToolIds.formUnion(discoveredEnabledToolIds)
        }
        return MCPToolDiscoveryPublication(
            configurationKeys: configurationKeys,
            enabledToolIds: enabledToolIds.sorted()
        )
    }
}

nonisolated struct MCPDiscoveryServerState: Sendable {
    let servers: [MCPServerInfo]
    let failedServerIds: Set<String>
}

private nonisolated extension MCPToolDiscoveryPublication {
    static func shouldRemove(
        toolId: String,
        serversById: [String: MCPServerInfo],
        failedServerIds: Set<String>
    ) -> Bool {
        guard let identity = MCPToolInfo.identity(from: toolId),
              let server = serversById[identity.serverId] else { return true }
        guard failedServerIds.contains(identity.serverId) else { return true }
        guard let allowedTools = server.allowedTools else { return false }
        return !allowedTools.contains(identity.name)
    }
}
