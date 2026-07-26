//
//  FetchMCPToolsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct MCPDiscoveryResult: Sendable {
    let servers: [MCPServerInfo]
    let tools: [MCPToolInfo]
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

            let tools = servers.flatMap { server in
                let toolNames = server.allowedTools ?? []
                return toolNames.map { name in
                    MCPToolInfo(
                        name: name,
                        description: nil,
                        serverId: server.serverName,
                        serverName: server.serverName,
                        inputSchema: nil
                    )
                }
            }
            return MCPDiscoveryResult(servers: servers, tools: tools)
        } catch {
            LogManager.debug("FetchMCPToolsUseCase: MCP not available — \(error.localizedDescription)")
            return empty
        }
    }
}
