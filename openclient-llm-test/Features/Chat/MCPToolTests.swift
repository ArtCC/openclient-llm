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
            repository: repository,
            permission: .alwaysAllow
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

        // When
        let caughtError: Error?
        do {
            _ = try await tool.execute(arguments: "not-json")
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? MCPToolError, .invalidArguments)
        XCTAssertNil(repository.serverId)
    }

    func test_execute_missingRequiredArgument_doesNotCallRepository() async {
        // Given
        let schema = MCPJSONSchema(
            type: nil,
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

        // When
        let caughtError: Error?
        do {
            _ = try await tool.execute(arguments: "{}")
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? MCPToolError, .argumentsDoNotMatchSchema)
        XCTAssertNil(repository.serverId)
    }

    func test_execute_configurationChanged_doesNotCallRepository() async {
        // Given
        let repository = MockMCPToolRepository()
        let tool = MCPTool(
            serverId: "srv-1",
            toolName: "GitHub-search",
            rawName: "search",
            description: "Search",
            parameters: ToolParameters(type: "object", properties: [:], required: []),
            repository: repository,
            isConfigurationCurrent: { false }
        )

        // When
        let caughtError: Error?
        do {
            _ = try await tool.execute(arguments: "{}")
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? MCPToolError, .configurationChanged)
        XCTAssertNil(repository.serverId)
    }

    func test_execute_askPermissionWithoutPermit_doesNotCallRepository() async {
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
        let caughtError: Error?
        do {
            _ = try await tool.execute(arguments: "{}")
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? MCPToolError, .authorizationChanged)
        XCTAssertNil(repository.serverId)
    }

    func test_execute_additionalPropertyDisallowed_doesNotCallRepository() async {
        // Given
        let schema = MCPJSONSchema(
            type: nil,
            properties: ["query": MCPJSONSchema(
                type: "string",
                properties: nil,
                required: nil,
                description: nil,
                items: nil,
                enum: nil
            )],
            required: ["query"],
            description: nil,
            items: nil,
            enum: nil,
            additionalProperties: .allowed(false)
        )
        let repository = MockMCPToolRepository()
        let tool = MCPTool(
            serverId: "srv-1",
            toolName: "GitHub-search",
            rawName: "search",
            description: "Search",
            parameters: MCPTool.toolParameters(from: schema),
            repository: repository,
            inputSchema: schema,
            permission: .alwaysAllow
        )

        // When
        let caughtError: Error?
        do {
            _ = try await tool.execute(arguments: #"{"query":"Swift","unexpected":true}"#)
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? MCPToolError, .argumentsDoNotMatchSchema)
        XCTAssertNil(repository.serverId)
    }

    func test_toolParameters_additionalPropertiesFalse_encodesConstraint() throws {
        // Given
        let schema = MCPJSONSchema(
            type: "object",
            properties: [:],
            required: [],
            description: nil,
            items: nil,
            enum: nil,
            additionalProperties: .allowed(false)
        )

        // When
        let data = try JSONEncoder().encode(MCPTool.toolParameters(from: schema))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        // Then
        XCTAssertTrue(json.contains("\"additionalProperties\":false"))
    }

    func test_authorizationMetadata_untrustedControlCharacters_sanitizesDisplayText() {
        // Given
        let tool = MCPTool(
            serverId: "server-id",
            toolName: "Server-tool",
            rawName: "safe\u{202E}evil\nnext",
            description: "Do\u{0000}thing",
            parameters: ToolParameters(type: "object", properties: [:], required: []),
            serverName: "Git\nHub"
        )

        // When
        let metadata = tool.authorizationMetadata

        // Then
        XCTAssertEqual(metadata.displayName, "safeevil next")
        XCTAssertEqual(metadata.serverName, "Git Hub")
        XCTAssertEqual(metadata.toolDescription, "Do thing")
    }

    func test_execute_omittedTypeEnumReceivesNumber_rejectsArguments() async {
        // Given
        let schema = MCPJSONSchema(
            type: "object",
            properties: ["mode": MCPJSONSchema(
                type: nil,
                properties: nil,
                required: nil,
                description: nil,
                items: nil,
                enum: ["read"]
            )],
            required: ["mode"],
            description: nil,
            items: nil,
            enum: nil
        )
        let tool = MCPTool(
            serverId: "server",
            toolName: "tool",
            rawName: "tool",
            description: "Tool",
            parameters: MCPTool.toolParameters(from: schema),
            inputSchema: schema,
            permission: .alwaysAllow
        )

        // When
        let caughtError: Error?
        do {
            _ = try await tool.execute(arguments: #"{"mode":1}"#)
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? MCPToolError, .argumentsDoNotMatchSchema)
    }

    func test_toolParameters_nestedObjectWithoutType_infersObjectType() {
        // Given
        let nestedSchema = MCPJSONSchema(
            type: nil,
            properties: [:],
            required: [],
            description: nil,
            items: nil,
            enum: nil
        )
        let schema = MCPJSONSchema(
            type: "object",
            properties: ["configuration": nestedSchema],
            required: [],
            description: nil,
            items: nil,
            enum: nil
        )

        // When
        let parameters = MCPTool.toolParameters(from: schema)

        // Then
        XCTAssertEqual(parameters.properties["configuration"]?.type, "object")
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
