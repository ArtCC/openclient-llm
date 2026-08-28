//
//  ChatViewModelTests+MCPAuthorization.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension ChatViewModelTests {
    func test_send_stopStreamingTapped_withPendingMCPAuthorization_cancelsAuthorization() async {
        // Given
        sut.state = .loaded(ChatViewModel.LoadedState(isStreaming: true))
        let request = MCPToolAuthorizationRequest(
            id: UUID(),
            toolCallId: "call-1",
            toolName: "GitHub-create_issue",
            arguments: "{}",
            metadata: MCPToolAuthorizationMetadata(
                toolId: "github-create_issue",
                displayName: "create_issue",
                serverName: "GitHub",
                toolDescription: nil,
                permissionKey: "permission-key",
                permission: .ask
            )
        )
        let task = Task { try await sut.mcpAuthorizationCoordinator.authorize([request]) }
        for _ in 0..<100 {
            if sut.mcpAuthorizationCoordinator.pendingBatch != nil { break }
            await Task.yield()
        }
        guard sut.mcpAuthorizationCoordinator.pendingBatch != nil else {
            task.cancel()
            sut.mcpAuthorizationCoordinator.cancelPending()
            _ = try? await task.value
            XCTFail("Expected a pending MCP authorization batch")
            return
        }

        // When
        sut.send(.stopStreamingTapped)

        // Then
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertNil(sut.mcpAuthorizationCoordinator.pendingBatch)
    }

    func test_applyAgentEvent_mcpToolStarted_tracksToolWithoutShowingWebSearch() {
        // Given
        var loadedState = ChatViewModel.LoadedState()
        let toolCall = ToolCall(
            id: "mcp-call",
            type: "function",
            function: ToolCallFunction(name: "GitHub-create_issue", arguments: "{}")
        )

        // When
        sut.applyAgentEvent(.toolCallStarted(toolCall), to: &loadedState, assistantMessageId: UUID())

        // Then
        XCTAssertFalse(loadedState.isSearchingWeb)
        XCTAssertEqual(loadedState.activeToolNamesById[toolCall.id], toolCall.function.name)
    }

    func test_send_mcpToolPermissionChanged_updatesChatStateAndSettings() {
        // Given
        let settings = MockSettingsManager()
        settings.serverBaseURL = "https://example.com"
        let tool = MCPToolInfo(
            name: "create_issue",
            description: "Create an issue",
            serverId: "github",
            serverName: "GitHub",
            inputSchema: nil
        )
        let viewModel = ChatViewModel(
            state: .loaded(ChatViewModel.LoadedState(
                availableMCPTools: [tool],
                availableMCPServers: [],
                enabledMCPToolIds: [tool.id],
                mcpToolPermissions: [tool.id: .ask]
            )),
            settingsManager: settings
        )

        // When
        viewModel.send(.mcpToolPermissionChanged(toolId: tool.id, permission: .alwaysAllow))

        // Then
        let permissionKey = tool.permissionKey(
            serverBaseURL: settings.serverBaseURL,
            authorizationScope: settings.mcpAuthorizationScope
        )
        XCTAssertEqual(settings.mcpToolPermissions[permissionKey], .alwaysAllow)
        guard case .loaded(let loadedState) = viewModel.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.mcpToolPermissions[tool.id], .alwaysAllow)
    }

    func test_send_mcpToolsToggled_enablesAllToolsInSingleWrite() {
        // Given
        let settings = MockSettingsManager()
        let first = MCPToolInfo(
            name: "first", description: nil, serverId: "github", serverName: "GitHub", inputSchema: nil
        )
        let second = MCPToolInfo(
            name: "second", description: nil, serverId: "github", serverName: "GitHub", inputSchema: nil
        )
        let viewModel = ChatViewModel(
            state: .loaded(ChatViewModel.LoadedState(availableMCPTools: [first, second])),
            settingsManager: settings
        )

        // When
        viewModel.send(.mcpToolsToggled(toolIds: [first.id, second.id], enabled: true))

        // Then
        XCTAssertEqual(settings.enabledMCPToolWriteCount, 1)
        XCTAssertEqual(Set(settings.enabledMCPToolIds), [first.id, second.id])
        guard case .loaded(let loadedState) = viewModel.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.enabledMCPToolIds, [first.id, second.id])
    }

    func test_agentToolDefinitions_mixedAvailability_advertisesOnlyCurrentSupportedTool() {
        // Given
        let settings = MockSettingsManager()
        settings.serverBaseURL = "https://example.com"
        let staleTool = MCPToolInfo(
            name: "stale", description: nil, serverId: "failed", serverName: "Failed", inputSchema: nil
        )
        let unsupportedTool = MCPToolInfo(
            name: "unsupported",
            description: nil,
            serverId: "available",
            serverName: "Available",
            inputSchema: nil,
            rawInputSchemaData: Data("\"placeholder\"".utf8),
            isInputSchemaSupported: false
        )
        let currentTool = MCPToolInfo(
            name: "current", description: nil, serverId: "available", serverName: "Available", inputSchema: nil
        )
        for tool in [staleTool, unsupportedTool, currentTool] {
            settings.mcpToolConfigurationKeys[tool.id] = tool.permissionKey(
                serverBaseURL: settings.serverBaseURL,
                authorizationScope: settings.mcpAuthorizationScope
            )
        }
        settings.enabledMCPToolIds = [staleTool.id, unsupportedTool.id, currentTool.id]
        let model = LLMModel(id: "gpt-4", capabilities: [.functionCalling])
        let loadedState = ChatViewModel.LoadedState(
            selectedModel: model,
            availableMCPTools: [staleTool, unsupportedTool, currentTool],
            failedMCPServerIds: ["failed"],
            enabledMCPToolIds: [staleTool.id, unsupportedTool.id, currentTool.id],
            mcpDiscoveryScope: settings.mcpAuthorizationScope
        )
        let viewModel = ChatViewModel(state: .loaded(loadedState), settingsManager: settings)

        // When
        let definitions = viewModel.agentToolDefinitions(for: loadedState)

        // Then
        XCTAssertFalse(definitions.contains { $0.function.name == staleTool.prefixedName })
        XCTAssertFalse(definitions.contains { $0.function.name == unsupportedTool.prefixedName })
        XCTAssertTrue(definitions.contains { $0.function.name == currentTool.prefixedName })

        // When
        settings.mcpDiscoveryFailed = true
        let definitionsAfterSharedFailure = viewModel.agentToolDefinitions(for: loadedState)

        // Then
        XCTAssertFalse(definitionsAfterSharedFailure.contains { $0.function.name == currentTool.prefixedName })
    }

    func test_agentToolDefinitions_enabledGitHubToolWithStandardConstraints_advertisesTool() throws {
        // Given
        let data = Data(#"""
        {
        "name":"search_repositories",
        "inputSchema":{
            "type":"object",
            "properties":{"page":{"type":"number","minimum":1,"maximum":100}}
        }
        }
        """#.utf8)
        let server = MCPServerInfo(
            serverId: "github",
            serverName: "GitHub",
            description: nil,
            allowedTools: nil
        )
        let tool = try JSONDecoder().decode(MCPToolInfo.self, from: data).withServer(server)
        let settings = MockSettingsManager()
        settings.serverBaseURL = "https://example.com"
        settings.enabledMCPToolIds = [tool.id]
        settings.mcpToolConfigurationKeys[tool.id] = tool.permissionKey(
            serverBaseURL: settings.serverBaseURL,
            authorizationScope: settings.mcpAuthorizationScope
        )
        let model = LLMModel(id: "gpt-4", capabilities: [.functionCalling])
        let loadedState = ChatViewModel.LoadedState(
            selectedModel: model,
            availableMCPTools: [tool],
            enabledMCPToolIds: [tool.id],
            mcpDiscoveryScope: settings.mcpAuthorizationScope
        )
        let viewModel = ChatViewModel(state: .loaded(loadedState), settingsManager: settings)

        // When
        let definitions = viewModel.agentToolDefinitions(for: loadedState)

        // Then
        XCTAssertTrue(definitions.contains { $0.function.name == tool.prefixedName })
    }

    func test_observeMCPToolSettingsChanges_serverScopeChanges_cancelsActiveStream() async {
        // Given
        let settings = MockSettingsManager()
        settings.mcpAuthorizationScope = "original-scope"
        let agentStream = MockAgentStreamUseCase()
        agentStream.waitsForCancellation = true
        let model = LLMModel(id: "gpt-4", capabilities: [.functionCalling])
        let viewModel = ChatViewModel(
            state: .loaded(ChatViewModel.LoadedState(
                inputText: "Use a tool",
                selectedModel: model,
                availableModels: [model]
            )),
            agentStreamUseCase: agentStream,
            saveConversationUseCase: mockSaveConversation,
            fetchMCPToolsUseCase: MockFetchMCPToolsUseCase(),
            settingsManager: settings,
            streamingBackgroundUseCase: MockStreamingBackgroundUseCase(),
            notifyStreamingCompletedUseCase: MockNotifyStreamingCompletedUseCase()
        )
        viewModel.send(.sendTapped)
        await waitUntil { agentStream.executeCallCount == 1 }
        settings.mcpAuthorizationScope = "replacement-scope"

        // When
        for _ in 0..<100 where !agentStream.didTerminate {
            NotificationCenter.default.post(name: .mcpToolSettingsDidChange, object: nil)
            await Task.yield()
        }

        // Then
        guard case .loaded(let loadedState) = viewModel.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isStreaming)
        XCTAssertTrue(agentStream.didTerminate)
    }
}
