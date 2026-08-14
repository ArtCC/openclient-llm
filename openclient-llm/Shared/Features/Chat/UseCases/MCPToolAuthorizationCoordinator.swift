//
//  MCPToolAuthorizationCoordinator.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class MCPToolAuthorizationCoordinator: MCPToolAuthorizing {
    // MARK: - Properties

    private(set) var pendingBatch: MCPToolAuthorizationBatch?
    private(set) var submissionError: String?
    private(set) var conflictedPermissionKeys: Set<String> = []

    @ObservationIgnored
    private var continuation: CheckedContinuation<[UUID: MCPToolAuthorizationDecision], Error>?
    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }

    // MARK: - Authorization

    func authorize(
        _ requests: [MCPToolAuthorizationRequest]
    ) async throws -> [UUID: MCPToolAuthorizationDecision] {
        guard !requests.isEmpty else { return [:] }
        cancelPending()
        submissionError = nil
        conflictedPermissionKeys = []
        let batchId = UUID()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                pendingBatch = MCPToolAuthorizationBatch(
                    id: batchId,
                    requests: requests,
                    decisions: [:]
                )
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                self?.cancelPending(batchId: batchId)
            }
        }
    }

    func select(_ decision: MCPToolAuthorizationDecision, for requestId: UUID, batchId: UUID) {
        guard var batch = pendingBatch, batch.id == batchId,
              let selectedRequest = batch.requests.first(where: { $0.id == requestId }) else { return }
        let permissionKey = selectedRequest.metadata.permissionKey
        guard !conflictedPermissionKeys.contains(permissionKey) || !decision.allowsExecution else { return }
        let matchingRequestIds = batch.requests
            .filter { $0.metadata.permissionKey == permissionKey }
            .map(\.id)
        if decision.isPermanent {
            for matchingRequestId in matchingRequestIds {
                batch.decisions[matchingRequestId] = decision
            }
        } else {
            let hasPermanentSelection = matchingRequestIds.contains {
                batch.decisions[$0]?.isPermanent == true
            }
            if hasPermanentSelection {
                for matchingRequestId in matchingRequestIds {
                    batch.decisions.removeValue(forKey: matchingRequestId)
                }
            }
            batch.decisions[requestId] = decision
        }
        pendingBatch = batch
        if conflictedPermissionKeys.contains(permissionKey) {
            let isResolvedWithDenials = matchingRequestIds.allSatisfy { requestId in
                guard let selectedDecision = batch.decisions[requestId] else { return false }
                return !selectedDecision.allowsExecution
            }
            if isResolvedWithDenials { conflictedPermissionKeys.remove(permissionKey) }
        }
        if conflictedPermissionKeys.isEmpty { submissionError = nil }
    }

    func submit(batchId: UUID) {
        guard let batch = pendingBatch, batch.id == batchId, batch.isComplete else { return }
        let requestsByPermissionKey = Dictionary(grouping: batch.requests, by: { $0.metadata.permissionKey })
        let requestsRequiringCurrentState = batch.requests.filter { request in
            guard let decision = batch.decisions[request.id] else { return false }
            return decision.allowsExecution || decision.isPermanent
        }
        let stalePermissionKeys = Set(requestsRequiringCurrentState.compactMap { request in
            isRequestCurrent(request) ? nil : request.metadata.permissionKey
        })
        guard stalePermissionKeys.isEmpty else {
            conflictedPermissionKeys = stalePermissionKeys
            var revisedBatch = batch
            for request in batch.requests where stalePermissionKeys.contains(request.metadata.permissionKey) {
                revisedBatch.decisions.removeValue(forKey: request.id)
            }
            pendingBatch = revisedBatch
            submissionError = String(localized: """
                MCP tool settings changed. Affected allow decisions were cleared. Deny those calls or close this review.
                """)
            return
        }
        for requests in requestsByPermissionKey.values {
            let decisions = requests.compactMap { batch.decisions[$0.id] }
            guard decisions.contains(where: \.isPermanent) else { continue }
            if decisions.contains(.alwaysDeny), let permissionKey = requests.first?.metadata.permissionKey {
                settingsManager.setMCPToolPermission(.deny, for: permissionKey)
            } else if decisions.contains(.alwaysAllow), let permissionKey = requests.first?.metadata.permissionKey {
                settingsManager.setMCPToolPermission(.alwaysAllow, for: permissionKey)
            }
        }
        finish(with: .success(batch.decisions))
    }

    func dismiss(batchId: UUID) {
        guard var batch = pendingBatch, batch.id == batchId else { return }
        for request in batch.requests {
            batch.decisions[request.id] = .denyOnce
        }
        finish(with: .success(batch.decisions))
    }

    func cancelPending() {
        guard continuation != nil || pendingBatch != nil else { return }
        finish(with: .failure(CancellationError()))
    }
}

private extension MCPToolAuthorizationCoordinator {
    func isRequestCurrent(_ request: MCPToolAuthorizationRequest) -> Bool {
        settingsManager.getEnabledMCPToolIds().contains(request.metadata.toolId)
            && settingsManager.getMCPToolConfigurationKey(for: request.metadata.toolId)
                == request.metadata.permissionKey
            && settingsManager.getMCPToolPermission(for: request.metadata.permissionKey)
                == request.metadata.permission
    }

    func cancelPending(batchId: UUID) {
        guard pendingBatch?.id == batchId else { return }
        cancelPending()
    }

    func finish(with result: Result<[UUID: MCPToolAuthorizationDecision], Error>) {
        let currentContinuation = continuation
        continuation = nil
        pendingBatch = nil
        submissionError = nil
        conflictedPermissionKeys = []
        currentContinuation?.resume(with: result)
    }
}
