//
//  FetchMCPToolsUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class FetchMCPToolsUseCaseTests: XCTestCase {
    func test_execute_fetchesToolsByServerId_andAssociatesServerMetadata() async {
        // Given
        let server = MCPServerInfo(
            serverId: "srv-1",
            serverName: "GitHub",
            description: nil,
            allowedTools: nil
        )
        let repository = MockMCPRepository(
            servers: [server],
            toolsByServerId: ["srv-1": [MCPToolInfo(
                name: "search",
                description: "Search",
                serverId: "",
                serverName: "",
                inputSchema: nil
            )]]
        )
        let settings = MockSettingsManager()
        settings.serverBaseURL = "https://example.com"
        let sut = FetchMCPToolsUseCase(repository: repository, settingsManager: settings)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(repository.requestedServerIds, ["srv-1"])
        XCTAssertEqual(result.tools.first?.serverId, "srv-1")
        XCTAssertEqual(result.tools.first?.serverName, "GitHub")
        XCTAssertNil(result.errorMessage)
    }

    func test_execute_filtersToolsUsingLiteLLMAllowedTools() async {
        // Given
        let server = MCPServerInfo(
            serverId: "srv-1",
            serverName: "GitHub",
            description: nil,
            allowedTools: ["search"]
        )
        let repository = MockMCPRepository(
            servers: [server],
            toolsByServerId: ["srv-1": [
                MCPToolInfo(name: "search", description: nil, serverId: "", serverName: "", inputSchema: nil),
                MCPToolInfo(name: "delete", description: nil, serverId: "", serverName: "", inputSchema: nil)
            ]]
        )
        let settings = MockSettingsManager()
        settings.serverBaseURL = "https://example.com"
        let sut = FetchMCPToolsUseCase(repository: repository, settingsManager: settings)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.tools.map(\.name), ["search"])
    }

    func test_execute_whenOneServerFails_keepsOtherServersAndReportsWarning() async {
        // Given
        let goodServer = MCPServerInfo(serverId: "good", serverName: "Good", description: nil, allowedTools: nil)
        let badServer = MCPServerInfo(serverId: "bad", serverName: "Bad", description: nil, allowedTools: nil)
        let repository = MockMCPRepository(
            servers: [goodServer, badServer],
            toolsByServerId: ["good": [MCPToolInfo(
                name: "search",
                description: nil,
                serverId: "",
                serverName: "",
                inputSchema: nil
            )]],
            failingServerIds: ["bad", "Bad"]
        )
        let settings = MockSettingsManager()
        settings.serverBaseURL = "https://example.com"
        let sut = FetchMCPToolsUseCase(repository: repository, settingsManager: settings)

        // When
        let result = await sut.execute()

        // Then
        XCTAssertEqual(result.servers.count, 2)
        XCTAssertEqual(result.tools.map(\.serverId), ["good"])
        XCTAssertNotNil(result.errorMessage)
    }
}

// Safety: Only used within serialized @MainActor test methods.
private final class MockMCPRepository: MCPRepositoryProtocol, @unchecked Sendable {
    let servers: [MCPServerInfo]
    let toolsByServerId: [String: [MCPToolInfo]]
    let failingServerIds: Set<String>
    private(set) var requestedServerIds: [String] = []

    init(
        servers: [MCPServerInfo],
        toolsByServerId: [String: [MCPToolInfo]],
        failingServerIds: Set<String> = []
    ) {
        self.servers = servers
        self.toolsByServerId = toolsByServerId
        self.failingServerIds = failingServerIds
    }

    func fetchServers() async throws -> [MCPServerInfo] {
        servers
    }

    func fetchTools(serverId: String) async throws -> [MCPToolInfo] {
        requestedServerIds.append(serverId)
        if failingServerIds.contains(serverId) {
            throw APIError.serverUnreachable
        }
        return toolsByServerId[serverId] ?? []
    }

    func executeTool(serverId: String, toolName: String, arguments: String) async throws -> String {
        ""
    }
}
