//
//  FetchMCPToolsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct MCPDiscoveryResult: Sendable {
    let servers: [MCPServerInfo]
    let tools: [MCPToolInfo]
    let errorMessage: String?
    let failedServerIds: Set<String>

    init(
        servers: [MCPServerInfo],
        tools: [MCPToolInfo],
        errorMessage: String? = nil,
        failedServerIds: Set<String> = []
    ) {
        self.servers = servers
        self.tools = tools
        self.errorMessage = errorMessage
        self.failedServerIds = failedServerIds
    }
}

protocol FetchMCPToolsUseCaseProtocol: Sendable {
    func execute() async -> MCPDiscoveryResult
}

struct FetchMCPToolsUseCase: FetchMCPToolsUseCaseProtocol {
    // MARK: - Properties

    private let repository: MCPRepositoryProtocol
    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(
        repository: MCPRepositoryProtocol = MCPRepository(),
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.repository = repository
        self.settingsManager = settingsManager
    }

    // MARK: - Execute

    func execute() async -> MCPDiscoveryResult {
        let empty = MCPDiscoveryResult(servers: [], tools: [])
        guard !settingsManager.getServerBaseURL().isEmpty else { return empty }
        do {
            let servers = try await repository.fetchServers()
            guard !servers.isEmpty else { return empty }

            var tools: [MCPToolInfo] = []
            var failedServerNames: [String] = []
            var failedServerIds: Set<String> = []
            for server in servers {
                do {
                    let discoveredTools = try await repository.fetchTools(serverId: server.serverId)
                    let allowedTools = server.allowedTools
                    tools += discoveredTools
                        .map { $0.withServer(server) }
                        .filter { tool in
                            guard let allowedTools else { return true }
                            return allowedTools.contains(tool.name)
                        }
                } catch {
                    failedServerNames.append(server.serverName)
                    failedServerIds.insert(server.serverId)
                }
            }
            let errorMessage = failedServerNames.isEmpty ? nil : String(
                localized: "Some MCP servers could not be loaded: \(failedServerNames.joined(separator: ", "))."
            )
            return MCPDiscoveryResult(
                servers: servers,
                tools: tools,
                errorMessage: errorMessage,
                failedServerIds: failedServerIds
            )
        } catch {
            LogManager.debug("FetchMCPToolsUseCase: MCP not available — \(error.localizedDescription)")
            return MCPDiscoveryResult(
                servers: [],
                tools: [],
                errorMessage: error.localizedDescription
            )
        }
    }
}
