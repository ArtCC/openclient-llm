//
//  ToolRegistryTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ToolRegistryTests: XCTestCase {
    // MARK: - Tests — init / definitions

    func test_init_withEmptyTools_producesEmptyDefinitions() {
        let sut = ToolRegistry(tools: [])
        XCTAssertTrue(sut.definitions.isEmpty)
    }

    func test_init_withTools_producesCorrectDefinitions() {
        let tool = MockChatTool(name: "test_tool")
        let sut = ToolRegistry(tools: [tool])
        XCTAssertEqual(sut.definitions.count, 1)
        XCTAssertEqual(sut.definitions.first?.function.name, "test_tool")
    }

    // MARK: - Tests — execute

    func test_execute_knownTool_delegatesToTool() async throws {
        // Given
        let tool = MockChatTool(name: "greet", executionResult: ToolExecutionResult(text: "hello"))
        let sut = ToolRegistry(tools: [tool])

        // When
        let result = try await sut.execute(toolName: "greet", arguments: "{}")

        // Then
        XCTAssertEqual(result.text, "hello")
        XCTAssertEqual(tool.lastArguments, "{}")
    }

    func test_execute_unknownTool_returnsErrorText() async throws {
        // Given
        let sut = ToolRegistry(tools: [])

        // When
        let result = try await sut.execute(toolName: "nonexistent", arguments: "{}")

        // Then
        XCTAssertTrue(result.text.contains("Unknown tool"))
    }

    // MARK: - Tests — default factory

    func test_default_withWebSearchEnabled_includesWebSearchTool() {
        let sut = ToolRegistry.default(webSearchEnabled: true)
        let names = sut.definitions.map(\.function.name)
        XCTAssertTrue(names.contains("web_search"))
    }

    func test_default_withWebSearchDisabled_excludesWebSearchTool() {
        let sut = ToolRegistry.default(webSearchEnabled: false)
        let names = sut.definitions.map(\.function.name)
        XCTAssertFalse(names.contains("web_search"))
    }

    func test_default_alwaysIncludesGetCurrentDatetimeTool() {
        let sut = ToolRegistry.default()
        let names = sut.definitions.map(\.function.name)
        XCTAssertTrue(names.contains("get_current_datetime"))
    }

    func test_default_withMemoryToolsEnabled_includesMemoryTools() {
        let sut = ToolRegistry.default(includesMemoryTools: true)
        let names = sut.definitions.map(\.function.name)
        XCTAssertTrue(names.contains("save_memory"))
        XCTAssertTrue(names.contains("delete_memory"))
    }

    func test_default_withMemoryToolsDisabled_excludesMemoryTools() {
        let sut = ToolRegistry.default(includesMemoryTools: false)
        let names = sut.definitions.map(\.function.name)
        XCTAssertFalse(names.contains("save_memory"))
        XCTAssertFalse(names.contains("delete_memory"))
    }
}

// MARK: - MockChatTool

// Safety: Only used within serialized @MainActor test methods.
private final class MockChatTool: ChatToolProtocol, @unchecked Sendable {
    let toolName: String
    var executionResult: ToolExecutionResult = ToolExecutionResult(text: "mock")
    var lastArguments: String?

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: toolName,
                description: "Mock tool",
                parameters: ToolParameters(type: "object", properties: [:], required: [])
            )
        )
    }

    init(name: String, executionResult: ToolExecutionResult = ToolExecutionResult(text: "mock")) {
        self.toolName = name
        self.executionResult = executionResult
    }

    func execute(arguments: String) async throws -> ToolExecutionResult {
        lastArguments = arguments
        return executionResult
    }
}
