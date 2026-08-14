//
//  AgentStreamUseCaseAuthorizationTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class AgentStreamUseCaseAuthorizationTests: XCTestCase {
    // MARK: - Tests

    func test_execute_mcpAskApproved_waitsBeforeExecutingAndCompletes() async throws {
        // Given
        let toolRepository = RecordingMCPToolRepository()
        let settings = MockSettingsManager()
        let toolId = MCPToolInfo.identifier(serverId: "github", name: "create_issue")
        settings.enabledMCPToolIds = [toolId]
        settings.mcpToolConfigurationKeys[toolId] = "github-create-issue"
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let registry = makeRegistry(permission: .ask, repository: toolRepository, coordinator: coordinator)
        let repository = AuthorizationAgentRepository(responses: toolRoundResponses())
        let sut = AgentStreamUseCase(repository: repository)

        // When
        let consumer = Task { try await consume(sut: sut, registry: registry) }
        let batch = try await waitForPendingBatch(in: coordinator)
        let callsBeforeApproval = toolRepository.executeCallCount

        // Then
        XCTAssertEqual(callsBeforeApproval, 0)

        // When
        let request = try XCTUnwrap(batch.requests.first)
        coordinator.select(.allowOnce, for: request.id, batchId: batch.id)
        coordinator.submit(batchId: batch.id)
        _ = try await consumer.value

        // Then
        let callsAfterApproval = toolRepository.executeCallCount
        XCTAssertEqual(callsAfterApproval, 1)
        XCTAssertEqual(repository.callIndex, 2)
        XCTAssertEqual(repository.requests.last?.filter { $0.role == .tool }.count, 1)
        let toolContent = try XCTUnwrap(repository.requests.last?.first(where: { $0.role == .tool })?.content)
        let toolData = try XCTUnwrap(toolContent.data(using: .utf8))
        let toolEnvelope = try JSONDecoder().decode([String: String].self, from: toolData)
        XCTAssertEqual(toolEnvelope["untrustedExternalToolResult"], "Created")
    }

    func test_execute_mcpAskDenied_doesNotExecuteAndSendsDenialResult() async throws {
        // Given
        let toolRepository = RecordingMCPToolRepository()
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let registry = makeRegistry(permission: .ask, repository: toolRepository, coordinator: coordinator)
        let repository = AuthorizationAgentRepository(responses: toolRoundResponses())
        let sut = AgentStreamUseCase(repository: repository)
        let consumer = Task { try await consume(sut: sut, registry: registry) }
        let batch = try await waitForPendingBatch(in: coordinator)
        let request = try XCTUnwrap(batch.requests.first)

        // When
        coordinator.select(.denyOnce, for: request.id, batchId: batch.id)
        coordinator.submit(batchId: batch.id)
        _ = try await consumer.value

        // Then
        let executeCallCount = toolRepository.executeCallCount
        XCTAssertEqual(executeCallCount, 0)
        let denial = repository.requests.last?.first(where: { $0.role == .tool })?.content
        XCTAssertTrue(denial?.contains("denied by the user") == true)
    }

    func test_execute_mcpAlwaysAllow_executesWithoutPrompt() async throws {
        // Given
        let toolRepository = RecordingMCPToolRepository()
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let registry = makeRegistry(
            permission: .alwaysAllow,
            repository: toolRepository,
            coordinator: coordinator
        )
        let repository = AuthorizationAgentRepository(responses: toolRoundResponses())
        let sut = AgentStreamUseCase(repository: repository)

        // When
        try await consume(sut: sut, registry: registry)

        // Then
        XCTAssertNil(coordinator.pendingBatch)
        let executeCallCount = toolRepository.executeCallCount
        XCTAssertEqual(executeCallCount, 1)
    }

    func test_execute_mcpDeny_blocksWithoutPromptAndContinues() async throws {
        // Given
        let toolRepository = RecordingMCPToolRepository()
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let registry = makeRegistry(permission: .deny, repository: toolRepository, coordinator: coordinator)
        let repository = AuthorizationAgentRepository(responses: toolRoundResponses())
        let sut = AgentStreamUseCase(repository: repository)

        // When
        try await consume(sut: sut, registry: registry)

        // Then
        XCTAssertNil(coordinator.pendingBatch)
        let executeCallCount = toolRepository.executeCallCount
        XCTAssertEqual(executeCallCount, 0)
        let denial = repository.requests.last?.first(where: { $0.role == .tool })?.content
        XCTAssertTrue(denial?.contains("user's policy") == true)
    }

    func test_execute_mixedAutomaticAndMCPAsk_pendingApprovalDoesNotStartAnyTool() async throws {
        // Given
        let automaticRecorder = ToolExecutionRecorder()
        let automaticTool = RecordingChatTool(name: "local_tool", recorder: automaticRecorder)
        let mcpRepository = RecordingMCPToolRepository()
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let mcpTool = makeMCPTool(permission: .ask, repository: mcpRepository)
        let registry = ToolRegistry(
            tools: [automaticTool, mcpTool],
            mcpAuthorizer: coordinator
        )
        let calls = [
            ToolCall(
                id: "local-call",
                type: "function",
                function: ToolCallFunction(name: "local_tool", arguments: "{}")
            ),
            makeMCPCall()
        ]
        let repository = AuthorizationAgentRepository(responses: toolRoundResponses(toolCalls: calls))
        let sut = AgentStreamUseCase(repository: repository)

        // When
        let consumer = Task { try await consume(sut: sut, registry: registry) }
        let batch = try await waitForPendingBatch(in: coordinator)

        // Then
        let automaticCallsBeforeApproval = await automaticRecorder.count
        let mcpCallsBeforeApproval = mcpRepository.executeCallCount
        XCTAssertEqual(automaticCallsBeforeApproval, 0)
        XCTAssertEqual(mcpCallsBeforeApproval, 0)

        coordinator.dismiss(batchId: batch.id)
        _ = try await consumer.value
    }

    func test_execute_cancelledDuringApproval_doesNotExecuteTool() async throws {
        // Given
        let toolRepository = RecordingMCPToolRepository()
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let registry = makeRegistry(permission: .ask, repository: toolRepository, coordinator: coordinator)
        let repository = AuthorizationAgentRepository(responses: toolRoundResponses())
        let sut = AgentStreamUseCase(repository: repository)
        let consumer = Task {
            do {
                try await consume(sut: sut, registry: registry)
                return nil as Error?
            } catch {
                return error
            }
        }
        _ = try await waitForPendingBatch(in: coordinator)

        // When
        consumer.cancel()
        _ = await consumer.value
        for _ in 0..<20 {
            if coordinator.pendingBatch == nil { break }
            await Task.yield()
        }

        // Then
        XCTAssertNil(coordinator.pendingBatch)
        let executeCallCount = toolRepository.executeCallCount
        XCTAssertEqual(executeCallCount, 0)
    }

    func test_execute_alwaysAllowSelected_appliesToLaterRoundWithoutPromptingAgain() async throws {
        // Given
        let suiteName = "com.artcc.openclient-llm.test.agent-permission-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let settings = SettingsManager(defaults: defaults, keychainManager: MockKeychainManager())
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let toolRepository = RecordingMCPToolRepository()
        let permissionKey = "github-create-issue"
        let registry = makePersistentPermissionRegistry(
            settings: settings,
            coordinator: coordinator,
            repository: toolRepository,
            permissionKey: permissionKey
        )
        let firstCall = makeMCPCall(id: "first-call")
        let secondCall = makeMCPCall(id: "second-call")
        let firstResponses = toolRoundResponses(toolCalls: [firstCall])
        let secondResponses = toolRoundResponses(toolCalls: [secondCall])
        let repository = AuthorizationAgentRepository(
            responses: [firstResponses[0], secondResponses[0], firstResponses[1]]
        )
        let sut = AgentStreamUseCase(repository: repository)
        let consumer = Task { try await consume(sut: sut, registry: registry) }
        let batch = try await waitForPendingBatch(in: coordinator)
        let request = try XCTUnwrap(batch.requests.first)

        // When
        coordinator.select(.alwaysAllow, for: request.id, batchId: batch.id)
        coordinator.submit(batchId: batch.id)
        let reachedTerminalState = await waitForAgentCompletionOrAuthorization(repository, coordinator: coordinator)
        guard reachedTerminalState else {
            consumer.cancel()
            coordinator.cancelPending()
            _ = try? await consumer.value
            XCTFail("Expected the agent to finish or request another authorization")
            return
        }
        if coordinator.pendingBatch != nil {
            XCTFail("Always Allow must apply to later rounds in the same response")
            if let pendingId = coordinator.pendingBatch?.id {
                coordinator.dismiss(batchId: pendingId)
            }
        }
        _ = try await consumer.value

        // Then
        let executeCallCount = toolRepository.executeCallCount
        XCTAssertEqual(executeCallCount, 2)
        XCTAssertEqual(settings.getMCPToolPermission(for: permissionKey), .alwaysAllow)
    }

    func test_execute_mcpInvalidArguments_rejectsWithoutPromptOrExecution() async throws {
        // Given
        let toolRepository = RecordingMCPToolRepository()
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let registry = makeRegistry(permission: .ask, repository: toolRepository, coordinator: coordinator)
        let invalidCall = ToolCall(
            id: "invalid-call",
            type: "function",
            function: ToolCallFunction(name: mcpFunctionName, arguments: "{")
        )
        let repository = AuthorizationAgentRepository(
            responses: toolRoundResponses(toolCalls: [invalidCall])
        )

        // When
        try await consume(sut: AgentStreamUseCase(repository: repository), registry: registry)

        // Then
        let executeCallCount = toolRepository.executeCallCount
        XCTAssertNil(coordinator.pendingBatch)
        XCTAssertEqual(executeCallCount, 0)
        let result = repository.requests.last?.first(where: { $0.role == .tool })?.content
        XCTAssertTrue(result?.contains(MCPToolError.invalidArguments.localizedDescription) == true)
    }

    func test_execute_nineMCPCalls_promptsForFirstEightAndRejectsNinthByBudget() async throws {
        // Given
        let toolRepository = RecordingMCPToolRepository()
        let coordinator = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let registry = makeRegistry(permission: .ask, repository: toolRepository, coordinator: coordinator)
        let calls = (0..<9).map { index in
            ToolCall(
                id: "mcp-call-\(index)",
                type: "function",
                function: ToolCallFunction(name: mcpFunctionName, arguments: "{}")
            )
        }
        let repository = AuthorizationAgentRepository(responses: toolRoundResponses(toolCalls: calls))
        let sut = AgentStreamUseCase(repository: repository)
        let consumer = Task { try await consume(sut: sut, registry: registry) }

        // When
        let batch = try await waitForPendingBatch(in: coordinator)
        coordinator.dismiss(batchId: batch.id)
        _ = try await consumer.value

        // Then
        XCTAssertEqual(batch.requests.count, 8)
        let toolResults = repository.requests.last?.filter { $0.role == .tool } ?? []
        XCTAssertEqual(toolResults.count, 9)
        XCTAssertTrue(toolResults.last?.content.contains("budget exceeded") == true)
    }

}

private extension AgentStreamUseCaseAuthorizationTests {
    func waitForAgentCompletionOrAuthorization(
        _ repository: AuthorizationAgentRepository,
        coordinator: MCPToolAuthorizationCoordinator
    ) async -> Bool {
        for _ in 0..<100 {
            if repository.callIndex >= 3 || coordinator.pendingBatch != nil { return true }
            await Task.yield()
        }
        return false
    }

    func makePersistentPermissionRegistry(
        settings: SettingsManagerProtocol,
        coordinator: MCPToolAuthorizationCoordinator,
        repository: RecordingMCPToolRepository,
        permissionKey: String
    ) -> ToolRegistry {
        let toolId = MCPToolInfo.identifier(serverId: "github", name: "create_issue")
        settings.setEnabledMCPToolIds([toolId])
        settings.setMCPToolConfigurationKey(permissionKey, for: toolId)
        let tool = MCPTool(
            serverId: "github",
            toolName: mcpFunctionName,
            rawName: "create_issue",
            description: "Create an issue",
            parameters: ToolParameters(type: "object", properties: [:], required: []),
            repository: repository,
            serverName: "GitHub",
            permissionKey: permissionKey,
            permissionProvider: { settings.getMCPToolPermission(for: permissionKey) }
        )
        return ToolRegistry(tools: [tool], mcpAuthorizer: coordinator)
    }

    func makeRegistry(
        permission: MCPToolPermission,
        repository: RecordingMCPToolRepository,
        coordinator: MCPToolAuthorizationCoordinator
    ) -> ToolRegistry {
        ToolRegistry(
            tools: [makeMCPTool(permission: permission, repository: repository)],
            mcpAuthorizer: coordinator
        )
    }

    func makeMCPTool(
        permission: MCPToolPermission,
        repository: RecordingMCPToolRepository
    ) -> MCPTool {
        MCPTool(
            serverId: "github",
            toolName: mcpFunctionName,
            rawName: "create_issue",
            description: "Create an issue",
            parameters: ToolParameters(type: "object", properties: [:], required: []),
            repository: repository,
            serverName: "GitHub",
            permissionKey: "github-create-issue",
            permission: permission
        )
    }

    func makeMCPCall(id: String = "mcp-call") -> ToolCall {
        ToolCall(
            id: id,
            type: "function",
            function: ToolCallFunction(name: mcpFunctionName, arguments: #"{"title":"Bug"}"#)
        )
    }

    func toolRoundResponses(toolCalls: [ToolCall]? = nil) -> [ChatCompletionResponse] {
        let calls = toolCalls ?? [makeMCPCall()]
        return [
            ChatCompletionResponse(
                id: "tool-round",
                choices: [ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Message(
                        role: "assistant",
                        content: nil,
                        reasoningContent: nil,
                        images: nil,
                        toolCalls: calls
                    ),
                    finishReason: "tool_calls"
                )],
                usage: nil
            ),
            ChatCompletionResponse(
                id: "final-round",
                choices: [ChatCompletionResponse.Choice(
                    message: ChatCompletionResponse.Message(
                        role: "assistant",
                        content: "Finished",
                        reasoningContent: nil,
                        images: nil,
                        toolCalls: nil
                    ),
                    finishReason: "stop"
                )],
                usage: nil
            )
        ]
    }

    var mcpFunctionName: String {
        MCPToolInfo(name: "create_issue", description: nil, serverId: "github", serverName: "GitHub", inputSchema: nil)
            .prefixedName
    }

    func consume(sut: AgentStreamUseCase, registry: ToolRegistry) async throws {
        for try await _ in sut.execute(
            messages: [ChatMessage(role: .user, content: "Create an issue")],
            model: "test-model",
            parameters: .default,
            toolRegistry: registry
        ) {}
    }

    func waitForPendingBatch(
        in coordinator: MCPToolAuthorizationCoordinator
    ) async throws -> MCPToolAuthorizationBatch {
        for _ in 0..<100 {
            if let batch = coordinator.pendingBatch { return batch }
            await Task.yield()
        }
        XCTFail("Expected a pending MCP authorization batch")
        throw AgentAuthorizationTestError.pendingBatchNotPresented
    }
}

private enum AgentAuthorizationTestError: Error {
    case pendingBatchNotPresented
}

@MainActor
private final class RecordingMCPToolRepository: MCPRepositoryProtocol {
    private(set) var executeCallCount = 0

    func fetchServers() async throws -> [MCPServerInfo] { [] }
    func fetchTools(serverId: String) async throws -> [MCPToolInfo] { [] }

    func executeTool(serverId: String, toolName: String, arguments: String) async throws -> String {
        executeCallCount += 1
        return "Created"
    }
}

private actor ToolExecutionRecorder {
    private(set) var count = 0

    func record() {
        count += 1
    }
}

private struct RecordingChatTool: ChatToolProtocol {
    let name: String
    let recorder: ToolExecutionRecorder

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: name,
                description: "Local test tool",
                parameters: ToolParameters(type: "object", properties: [:], required: [])
            )
        )
    }

    func execute(arguments: String) async throws -> ToolExecutionResult {
        await recorder.record()
        return ToolExecutionResult(text: "Local result")
    }
}
