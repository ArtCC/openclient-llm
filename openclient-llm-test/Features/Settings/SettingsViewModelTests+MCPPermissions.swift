//
//  SettingsViewModelTests+MCPPermissions.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension SettingsViewModelTests {
    func test_fetchMCPTools_newTool_defaultsPermissionToAsk() async {
        // Given
        let tool = makePermissionTool()
        mockFetchMCPTools.result = makeDiscoveryResult(tool: tool)

        // When
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [tool]
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.mcpToolPermissions[tool.id], .ask)
        let configurationKey = tool.permissionKey(
            serverBaseURL: mockSettingsManager.serverBaseURL,
            authorizationScope: mockSettingsManager.mcpAuthorizationScope
        )
        XCTAssertEqual(mockSettingsManager.mcpToolConfigurationKeys[tool.id], configurationKey)
    }

    func test_fetchMCPTools_secureScopeUnavailable_failsClosedWithoutDiscovery() {
        // Given
        mockSettingsManager.mcpAuthorizationScope = ""

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedState.mcpToolsError)
        XCTAssertTrue(loadedState.availableMCPTools.isEmpty)
        XCTAssertEqual(mockFetchMCPTools.executeCallCount, 0)
    }

    func test_fetchMCPTools_storedPermission_restoresPermission() async {
        // Given
        let tool = makePermissionTool()
        mockSettingsManager.serverBaseURL = "https://example.com"
        let permissionKey = tool.permissionKey(
            serverBaseURL: mockSettingsManager.serverBaseURL,
            authorizationScope: mockSettingsManager.mcpAuthorizationScope
        )
        mockSettingsManager.mcpToolPermissions[permissionKey] = .alwaysAllow
        mockFetchMCPTools.result = makeDiscoveryResult(tool: tool)

        // When
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [tool]
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.mcpToolPermissions[tool.id], .alwaysAllow)
    }

    func test_fetchMCPTools_legacyEnabledIdentifier_migratesToCollisionSafeIdentifier() async {
        // Given
        let tool = makePermissionTool()
        mockSettingsManager.enabledMCPToolIds = [tool.legacyId]
        mockFetchMCPTools.result = makeDiscoveryResult(tool: tool)

        // When
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [tool]
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.enabledMCPToolIds, [tool.id])
        XCTAssertEqual(mockSettingsManager.enabledMCPToolIds, [tool.id])
    }

    func test_send_mcpToolPermissionChanged_updatesStateAndSettings() async {
        // Given
        let tool = makePermissionTool()
        mockSettingsManager.serverBaseURL = "https://example.com"
        mockFetchMCPTools.result = makeDiscoveryResult(tool: tool)
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [tool]
        }

        // When
        sut.send(.mcpToolPermissionChanged(toolId: tool.id, permission: .deny))

        // Then
        let permissionKey = tool.permissionKey(
            serverBaseURL: mockSettingsManager.serverBaseURL,
            authorizationScope: mockSettingsManager.mcpAuthorizationScope
        )
        XCTAssertEqual(mockSettingsManager.mcpToolPermissions[permissionKey], .deny)
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.mcpToolPermissions[tool.id], .deny)
    }

    func test_fetchMCPTools_configurationChanges_discardsStaleDiscovery() async {
        // Given
        let controller = MCPDiscoveryController()
        mockFetchMCPTools.executeHandler = { await controller.waitForResult() }
        sut.send(.viewAppeared)
        await waitForDiscoveryCalls(1, controller: controller)

        let staleTool = makePermissionTool(name: "stale_tool")
        let currentTool = makePermissionTool(name: "current_tool")
        mockSettingsManager.mcpAuthorizationScope = "updated-scope"

        // When
        sut.fetchMCPTools(replacingCurrent: true)
        await waitForDiscoveryCalls(2, controller: controller)
        await controller.resumeNext(with: makeDiscoveryResult(tool: staleTool))
        await controller.resumeNext(with: makeDiscoveryResult(tool: currentTool))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [currentTool]
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.availableMCPTools, [currentTool])
    }

    func test_fetchMCPTools_olderWindowFinishesLast_preservesNewerConfigurationKey() async {
        // Given
        let controller = MCPDiscoveryController()
        mockFetchMCPTools.executeHandler = { await controller.waitForResult() }
        sut.state = .loaded(SettingsViewModel.LoadedState())
        let secondFetch = MockFetchMCPToolsUseCase()
        secondFetch.executeHandler = { await controller.waitForResult() }
        let secondViewModel = SettingsViewModel(
            state: .loaded(SettingsViewModel.LoadedState()),
            fetchMCPToolsUseCase: secondFetch,
            settingsManager: mockSettingsManager
        )
        let olderTool = makePermissionTool()
        let newerTool = MCPToolInfo(
            name: olderTool.name,
            description: "Updated behavior",
            serverId: olderTool.serverId,
            serverName: olderTool.serverName,
            inputSchema: nil
        )
        sut.fetchMCPTools()
        await waitForDiscoveryCalls(1, controller: controller)
        secondViewModel.fetchMCPTools()
        await waitForDiscoveryCalls(2, controller: controller)

        // When
        await controller.resumeLast(with: makeDiscoveryResult(tool: newerTool))
        await waitUntil {
            guard case .loaded(let state) = secondViewModel.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [newerTool]
        }
        await controller.resumeNext(with: makeDiscoveryResult(tool: olderTool))
        await waitForDiscoveryCalls(3, controller: controller)

        // Then
        let expectedKey = newerTool.permissionKey(
            serverBaseURL: mockSettingsManager.serverBaseURL,
            authorizationScope: mockSettingsManager.mcpAuthorizationScope
        )
        XCTAssertEqual(mockSettingsManager.mcpToolConfigurationKeys[olderTool.id], expectedKey)

        await controller.resumeNext(with: makeDiscoveryResult(tool: newerTool))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [newerTool]
        }
    }

    func test_fetchMCPTools_newScopePartialFailure_doesNotRetainPreviousTools() async {
        // Given
        let oldTool = makePermissionTool(name: "old_tool")
        mockFetchMCPTools.result = makeDiscoveryResult(tool: oldTool)
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [oldTool]
        }

        mockSettingsManager.mcpAuthorizationScope = "new-scope"
        mockFetchMCPTools.result = MCPDiscoveryResult(
            servers: [MCPServerInfo(
                serverId: "github",
                serverName: "GitHub",
                description: nil,
                allowedTools: nil
            )],
            tools: [],
            errorMessage: "Unavailable",
            failedServerIds: ["github"]
        )

        // When
        sut.fetchMCPTools(replacingCurrent: true)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.availableMCPTools.isEmpty)
        XCTAssertEqual(loadedState.mcpDiscoveryScope, "new-scope")
    }

    func test_fetchMCPTools_failedServerRemovesAllowedTool_doesNotRetainTool() async {
        // Given
        let oldTool = makePermissionTool(name: "old_tool")
        mockFetchMCPTools.result = makeDiscoveryResult(tool: oldTool)
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [oldTool]
        }
        mockFetchMCPTools.result = MCPDiscoveryResult(
            servers: [MCPServerInfo(
                serverId: oldTool.serverId,
                serverName: oldTool.serverName,
                description: nil,
                allowedTools: []
            )],
            tools: [],
            errorMessage: "Unavailable",
            failedServerIds: [oldTool.serverId]
        )

        // When
        sut.fetchMCPTools(replacingCurrent: true)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.availableMCPTools.isEmpty)
        XCTAssertNil(mockSettingsManager.mcpToolConfigurationKeys[oldTool.id])
    }

    func test_fetchMCPTools_fullFailure_retainsToolsButMarksEveryServerUnavailable() async {
        // Given
        let tool = makePermissionTool()
        mockFetchMCPTools.result = makeDiscoveryResult(tool: tool)
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.availableMCPTools == [tool]
        }
        mockFetchMCPTools.result = MCPDiscoveryResult(
            servers: [],
            tools: [],
            errorMessage: "Unavailable"
        )

        // When
        sut.fetchMCPTools(replacingCurrent: true)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return !state.isLoadingMCPTools && state.mcpToolsError != nil
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.availableMCPTools, [tool])
        XCTAssertEqual(loadedState.failedMCPServerIds, [tool.serverId])
    }
}

private extension SettingsViewModelTests {
    func makePermissionTool(name: String = "create_issue") -> MCPToolInfo {
        MCPToolInfo(
            name: name,
            description: "Create an issue",
            serverId: "github",
            serverName: "GitHub",
            inputSchema: nil
        )
    }

    func makeDiscoveryResult(tool: MCPToolInfo) -> MCPDiscoveryResult {
        MCPDiscoveryResult(
            servers: [MCPServerInfo(
                serverId: tool.serverId,
                serverName: tool.serverName,
                description: nil,
                allowedTools: nil
            )],
            tools: [tool]
        )
    }

    func waitForDiscoveryCalls(_ count: Int, controller: MCPDiscoveryController) async {
        for _ in 0..<100 {
            if await controller.callCount >= count { return }
            await Task.yield()
        }
        XCTFail("Expected \(count) MCP discovery call(s)")
    }
}

private actor MCPDiscoveryController {
    private(set) var callCount = 0
    private var continuations: [CheckedContinuation<MCPDiscoveryResult, Never>] = []

    func waitForResult() async -> MCPDiscoveryResult {
        callCount += 1
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeNext(with result: MCPDiscoveryResult) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(returning: result)
    }

    func resumeLast(with result: MCPDiscoveryResult) {
        guard !continuations.isEmpty else { return }
        continuations.removeLast().resume(returning: result)
    }
}
