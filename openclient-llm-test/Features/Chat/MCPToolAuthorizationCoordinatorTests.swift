//
//  MCPToolAuthorizationCoordinatorTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MCPToolAuthorizationCoordinatorTests: XCTestCase {
    // MARK: - Tests

    func test_authorize_allowOnce_waitsForSubmissionAndReturnsDecision() async throws {
        // Given
        let settings = MockSettingsManager()
        let sut = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let request = makeRequest()
        settings.enabledMCPToolIds = [request.metadata.toolId]
        settings.mcpToolConfigurationKeys[request.metadata.toolId] = request.metadata.permissionKey
        let task = Task { try await sut.authorize([request]) }
        try await waitForPendingBatch(in: sut)

        // When
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)
        sut.select(.allowOnce, for: request.id, batchId: batchId)
        sut.submit(batchId: batchId)
        let decisions = try await task.value

        // Then
        XCTAssertEqual(decisions[request.id], .allowOnce)
        XCTAssertNil(sut.pendingBatch)
        XCTAssertTrue(settings.mcpToolPermissions.isEmpty)
    }

    func test_authorize_alwaysAllow_persistsPermissionOnSubmission() async throws {
        // Given
        let settings = MockSettingsManager()
        let sut = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let request = makeRequest(permissionKey: "github-create")
        settings.enabledMCPToolIds = [request.metadata.toolId]
        settings.mcpToolConfigurationKeys[request.metadata.toolId] = request.metadata.permissionKey
        let task = Task { try await sut.authorize([request]) }
        try await waitForPendingBatch(in: sut)

        // When
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)
        sut.select(.alwaysAllow, for: request.id, batchId: batchId)
        sut.submit(batchId: batchId)
        _ = try await task.value

        // Then
        XCTAssertEqual(settings.mcpToolPermissions["github-create"], .alwaysAllow)
    }

    func test_select_permanentDecisionForRepeatedTool_appliesToEveryRequest() async throws {
        // Given
        let sut = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let first = makeRequest()
        let second = makeRequest()
        let task = Task { try await sut.authorize([first, second]) }
        try await waitForPendingBatch(in: sut)
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)

        // When
        sut.select(.alwaysAllow, for: first.id, batchId: batchId)

        // Then
        XCTAssertEqual(sut.pendingBatch?.decisions[first.id], .alwaysAllow)
        XCTAssertEqual(sut.pendingBatch?.decisions[second.id], .alwaysAllow)

        sut.dismiss(batchId: batchId)
        _ = try await task.value
    }

    func test_select_oneTimeDecisionAfterPermanentDecision_clearsRepeatedToolSelections() async throws {
        // Given
        let sut = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let first = makeRequest()
        let second = makeRequest()
        let task = Task { try await sut.authorize([first, second]) }
        try await waitForPendingBatch(in: sut)
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)
        sut.select(.alwaysDeny, for: first.id, batchId: batchId)

        // When
        sut.select(.allowOnce, for: first.id, batchId: batchId)

        // Then
        XCTAssertEqual(sut.pendingBatch?.decisions[first.id], .allowOnce)
        XCTAssertNil(sut.pendingBatch?.decisions[second.id])
        XCTAssertFalse(sut.pendingBatch?.isComplete == true)

        sut.dismiss(batchId: batchId)
        _ = try await task.value
    }

    func test_submit_permissionRevokedWhilePending_keepsBatchOpenAndPreservesDenial() async throws {
        // Given
        let settings = MockSettingsManager()
        let sut = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let request = makeRequest(permissionKey: "github-create")
        settings.enabledMCPToolIds = [request.metadata.toolId]
        settings.mcpToolConfigurationKeys[request.metadata.toolId] = request.metadata.permissionKey
        let task = Task { try await sut.authorize([request]) }
        try await waitForPendingBatch(in: sut)
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)
        sut.select(.alwaysAllow, for: request.id, batchId: batchId)
        settings.mcpToolPermissions[request.metadata.permissionKey] = .deny

        // When
        sut.submit(batchId: batchId)

        // Then
        XCTAssertEqual(sut.pendingBatch?.id, batchId)
        XCTAssertNotNil(sut.submissionError)
        XCTAssertNil(sut.pendingBatch?.decisions[request.id])
        XCTAssertEqual(settings.mcpToolPermissions[request.metadata.permissionKey], .deny)

        sut.select(.allowOnce, for: request.id, batchId: batchId)
        XCTAssertNil(sut.pendingBatch?.decisions[request.id])
        XCTAssertNotNil(sut.submissionError)
        sut.select(.denyOnce, for: request.id, batchId: batchId)
        XCTAssertNil(sut.submissionError)

        sut.dismiss(batchId: batchId)
        let decisions = try await task.value
        XCTAssertEqual(decisions[request.id], .denyOnce)
    }

    func test_submit_allowOnceToolDisabledWhilePending_keepsBatchOpen() async throws {
        // Given
        let settings = MockSettingsManager()
        let sut = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let request = makeRequest()
        settings.enabledMCPToolIds = [request.metadata.toolId]
        settings.mcpToolConfigurationKeys[request.metadata.toolId] = request.metadata.permissionKey
        let task = Task { try await sut.authorize([request]) }
        try await waitForPendingBatch(in: sut)
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)
        sut.select(.allowOnce, for: request.id, batchId: batchId)
        settings.enabledMCPToolIds = []

        // When
        sut.submit(batchId: batchId)

        // Then
        XCTAssertEqual(sut.pendingBatch?.id, batchId)
        XCTAssertNotNil(sut.submissionError)
        XCTAssertNil(sut.pendingBatch?.decisions[request.id])

        sut.dismiss(batchId: batchId)
        _ = try await task.value
    }

    func test_submit_configurationKeyChangedWhilePending_keepsBatchOpenAndClearsAllow() async throws {
        // Given
        let settings = MockSettingsManager()
        let sut = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let request = makeRequest()
        settings.enabledMCPToolIds = [request.metadata.toolId]
        settings.mcpToolConfigurationKeys[request.metadata.toolId] = request.metadata.permissionKey
        let task = Task { try await sut.authorize([request]) }
        try await waitForPendingBatch(in: sut)
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)
        sut.select(.allowOnce, for: request.id, batchId: batchId)
        settings.mcpToolConfigurationKeys[request.metadata.toolId] = "changed-key"

        // When
        sut.submit(batchId: batchId)

        // Then
        XCTAssertNil(sut.pendingBatch?.decisions[request.id])
        XCTAssertTrue(sut.conflictedPermissionKeys.contains(request.metadata.permissionKey))

        sut.dismiss(batchId: batchId)
        _ = try await task.value
    }

    func test_dismiss_withSelectedPermanentAllow_deniesAllWithoutPersisting() async throws {
        // Given
        let settings = MockSettingsManager()
        let sut = MCPToolAuthorizationCoordinator(settingsManager: settings)
        let first = makeRequest()
        let second = makeRequest()
        let task = Task { try await sut.authorize([first, second]) }
        try await waitForPendingBatch(in: sut)

        // When
        let batchId = try XCTUnwrap(sut.pendingBatch?.id)
        sut.select(.alwaysAllow, for: first.id, batchId: batchId)
        sut.dismiss(batchId: batchId)
        let decisions = try await task.value

        // Then
        XCTAssertEqual(decisions[first.id], .denyOnce)
        XCTAssertEqual(decisions[second.id], .denyOnce)
        XCTAssertTrue(settings.mcpToolPermissions.isEmpty)
    }

    func test_cancelPending_whileWaiting_throwsCancellationAndClearsBatch() async throws {
        // Given
        let sut = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let task = Task { try await sut.authorize([makeRequest()]) }
        try await waitForPendingBatch(in: sut)

        // When
        sut.cancelPending()

        // Then
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertNil(sut.pendingBatch)
    }

    func test_select_staleBatchCallbacks_doNotResolveNewBatch() async throws {
        // Given
        let sut = MCPToolAuthorizationCoordinator(settingsManager: MockSettingsManager())
        let firstRequest = makeRequest()
        let firstTask = Task { try await sut.authorize([firstRequest]) }
        try await waitForPendingBatch(in: sut)
        let firstBatchId = sut.pendingBatch?.id
        sut.cancelPending()
        _ = try? await firstTask.value

        let secondRequest = makeRequest()
        let secondTask = Task { try await sut.authorize([secondRequest]) }
        try await waitForPendingBatch(in: sut)
        let secondBatchId = sut.pendingBatch?.id

        // When
        if let firstBatchId {
            sut.select(.alwaysAllow, for: firstRequest.id, batchId: firstBatchId)
            sut.submit(batchId: firstBatchId)
            sut.dismiss(batchId: firstBatchId)
        }

        // Then
        XCTAssertEqual(sut.pendingBatch?.id, secondBatchId)
        XCTAssertTrue(sut.pendingBatch?.decisions.isEmpty == true)

        if let secondBatchId {
            sut.dismiss(batchId: secondBatchId)
        }
        _ = try? await secondTask.value
    }
}

private extension MCPToolAuthorizationCoordinatorTests {
    func makeRequest(permissionKey: String = "permission-key") -> MCPToolAuthorizationRequest {
        MCPToolAuthorizationRequest(
            id: UUID(),
            toolCallId: UUID().uuidString,
            toolName: "github-create_issue",
            arguments: #"{"title":"Bug"}"#,
            metadata: MCPToolAuthorizationMetadata(
                toolId: MCPToolInfo.identifier(serverId: "github", name: "create_issue"),
                displayName: "create_issue",
                serverName: "GitHub",
                toolDescription: "Create an issue",
                permissionKey: permissionKey,
                permission: .ask
            )
        )
    }

    func waitForPendingBatch(in coordinator: MCPToolAuthorizationCoordinator) async throws {
        for _ in 0..<100 {
            if coordinator.pendingBatch != nil { return }
            await Task.yield()
        }
        XCTFail("Expected a pending MCP authorization batch")
        throw MCPAuthorizationTestError.pendingBatchNotPresented
    }
}

private enum MCPAuthorizationTestError: Error {
    case pendingBatchNotPresented
}
