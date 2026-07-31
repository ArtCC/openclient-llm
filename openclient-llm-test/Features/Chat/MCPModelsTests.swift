//
//  MCPModelsTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MCPModelsTests: XCTestCase {
    func test_decodeServersResponse_withLiteLLMDataEnvelope_returnsServers() throws {
        // Given
        let data = Data("""
        {"data":[{"server_id":"srv-1","server_name":"GitHub","description":"Repos","allowed_tools":["issues"]}]}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // When
        let response = try decoder.decode(MCPServersResponse.self, from: data)

        // Then
        XCTAssertEqual(response.data.first?.serverId, "srv-1")
        XCTAssertEqual(response.data.first?.serverName, "GitHub")
    }

    func test_decodeToolsResponse_withDirectArray_returnsTools() throws {
        // Given
        let data = Data("""
        [{"name":"search","description":"Search","inputSchema":{"type":"object","required":["query"]}}]
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // When
        let response = try decoder.decode(MCPToolsResponse.self, from: data)

        // Then
        XCTAssertEqual(response.data.first?.name, "search")
        XCTAssertEqual(response.data.first?.inputSchema?.required, ["query"])
    }

    func test_decodeTool_withProviderSpecificSchemaPlaceholder_keepsTool() throws {
        // Given
        let data = Data("""
        {"name":"search","inputSchema":"tool_input_schema"}
        """.utf8)
        let decoder = JSONDecoder()

        // When
        let tool = try decoder.decode(MCPToolInfo.self, from: data)

        // Then
        XCTAssertEqual(tool.name, "search")
        XCTAssertNil(tool.inputSchema)
    }

    func test_tool_withServer_preservesLiteLLMIdentityAndDisplayName() {
        // Given
        let tool = MCPToolInfo(
            name: "search",
            description: "Search",
            serverId: "",
            serverName: "",
            inputSchema: nil
        )
        let server = MCPServerInfo(
            serverId: "srv-1",
            serverName: "GitHub",
            description: nil,
            allowedTools: nil
        )

        // When
        let associatedTool = tool.withServer(server)

        // Then
        XCTAssertEqual(associatedTool.id, "srv-1-search")
        XCTAssertEqual(associatedTool.prefixedName, "GitHub-search")
    }
}
