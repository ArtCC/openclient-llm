//
//  MCPRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol MCPRepositoryProtocol: Sendable {
    func fetchServers() async throws -> [MCPServerInfo]
    func fetchTools(serverId: String) async throws -> [MCPToolInfo]
    func executeTool(serverId: String, toolName: String, arguments: String) async throws -> String
}

struct MCPRepository: MCPRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func fetchServers() async throws -> [MCPServerInfo] {
        try await apiClient.listMCPServers()
    }

    func fetchTools(serverId: String) async throws -> [MCPToolInfo] {
        try await apiClient.listMCPTools(serverId: serverId)
    }

    func executeTool(serverId: String, toolName: String, arguments: String) async throws -> String {
        try await apiClient.callMCPTool(serverId: serverId, toolName: toolName, arguments: arguments)
    }
}
