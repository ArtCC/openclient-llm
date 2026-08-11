//
//  MockEnableCloudSyncUseCase.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockEnableCloudSyncUseCase:
    EnableCloudSyncUseCaseProtocol,
    CloudSyncRuntimeCoordinating,
    @unchecked Sendable {
    var result: Result<CloudSyncEnablementPreflight, Error> = .success(.ready)
    var executeCallCount = 0
    var executeCancellationCallCount = 0
    var executeHandler: (@Sendable () async throws -> CloudSyncEnablementPreflight)?
    var startCallCount = 0
    var stopCallCount = 0
    var approveCurrentAccountCallCount = 0
    private var task: Task<Void, Never>?

    func execute() async throws -> CloudSyncEnablementPreflight {
        executeCallCount += 1
        do {
            let preflight: CloudSyncEnablementPreflight
            if let executeHandler {
                preflight = try await executeHandler()
            } else {
                preflight = try result.get()
            }
            try Task.checkCancellation()
            return preflight
        } catch is CancellationError {
            executeCancellationCallCount += 1
            throw CancellationError()
        }
    }

    func start(profileConflictHandler: (() -> Void)?) {
        startCallCount += 1
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            if (try? await execute()) == .profileConflict, !Task.isCancelled {
                result = .success(.ready)
                profileConflictHandler?()
            }
        }
    }

    func approveCurrentAccount(profileConflictHandler: (() -> Void)?) {
        approveCurrentAccountCallCount += 1
        start(profileConflictHandler: profileConflictHandler)
    }

    func stop() {
        stopCallCount += 1
        task?.cancel()
        task = nil
    }
}
