//
//  MCPToolTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MCPToolTests: XCTestCase {
    func test_execute_validArguments_usesServerIdAndRawToolName() async throws {
        // Given
        let repository = MockMCPToolRepository()
        let tool = MCPTool(
            serverId: "srv-1",
            toolName: "GitHub-search",
            rawName: "search",
            description: "Search",
            parameters: ToolParameters(type: "object", properties: [:], required: []),
            repository: repository
        )

        // When
        _ = try await tool.execute(arguments: "{}")

        // Then
        XCTAssertEqual(repository.serverId, "srv-1")
        XCTAssertEqual(repository.toolName, "search")
        XCTAssertEqual(repository.arguments, "{}")
    }

    func test_execute_invalidJSON_doesNotCallRepository() async {
        // Given
        let repository = MockMCPToolRepository()
        let tool = MCPTool(
            serverId: "srv-1",
            toolName: "GitHub-search",
            rawName: "search",
            description: "Search",
            parameters: ToolParameters(type: "object", properties: [:], required: []),
            repository: repository
        )

        // When / Then
        do {
            _ = try await tool.execute(arguments: "not-json")
            XCTFail("Expected invalid arguments to throw")
        } catch {
            XCTAssertNil(repository.serverId)
        }
    }

    func test_execute_missingRequiredArgument_doesNotCallRepository() async {
        // Given
        let schema = MCPJSONSchema(
            type: "object",
            properties: [
                "query": MCPJSONSchema(
                    type: "string",
                    properties: nil,
                    required: nil,
                    description: nil,
                    items: nil,
                    enum: nil
                )
            ],
            required: ["query"],
            description: nil,
            items: nil,
            enum: nil
        )
        let repository = MockMCPToolRepository()
        let tool = MCPTool(
            serverId: "srv-1",
            toolName: "GitHub-search",
            rawName: "search",
            description: "Search",
            parameters: MCPTool.toolParameters(from: schema),
            repository: repository,
            inputSchema: schema
        )

        // When / Then
        do {
            _ = try await tool.execute(arguments: "{}")
            XCTFail("Expected schema validation to throw")
        } catch {
            XCTAssertNil(repository.serverId)
        }
    }
}

// Safety: Only used within serialized @MainActor test methods.
private final class MockMCPToolRepository: MCPRepositoryProtocol, @unchecked Sendable {
    private(set) var serverId: String?
    private(set) var toolName: String?
    private(set) var arguments: String?

    func fetchServers() async throws -> [MCPServerInfo] { [] }
    func fetchTools(serverId: String) async throws -> [MCPToolInfo] { [] }

    func executeTool(serverId: String, toolName: String, arguments: String) async throws -> String {
        self.serverId = serverId
        self.toolName = toolName
        self.arguments = arguments
        return "ok"
    }
}
