//
//  CloudSynchronizationMutationGate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

actor CloudSynchronizationMutationGate {
    // MARK: - Properties

    static let shared = CloudSynchronizationMutationGate()

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private let id = UUID()
    private var ownerID: UUID?
    private var waiters: [Waiter] = []

    // MARK: - Public

    var pendingRequestCount: Int {
        waiters.count
    }

    func perform<Value: Sendable, Failure: Error & Sendable>(
        _ operation: @escaping @Sendable () async throws(Failure) -> Value
    ) async throws -> Value {
        if CloudSynchronizationMutationContext.ownedGateIDs.contains(id) {
            try Task.checkCancellation()
            return try await operation()
        }

        let requestID = UUID()
        try await acquire(requestID: requestID)
        do {
            try Task.checkCancellation()
            let value = try await CloudSynchronizationMutationContext.$ownedGateIDs.withValue(
                CloudSynchronizationMutationContext.ownedGateIDs.union([id])
            ) {
                try await operation()
            }
            release(requestID: requestID)
            return value
        } catch {
            release(requestID: requestID)
            throw error
        }
    }
}

// MARK: - Private

private extension CloudSynchronizationMutationGate {
    func acquire(requestID: UUID) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard ownerID != nil else {
                    ownerID = requestID
                    continuation.resume()
                    return
                }
                waiters.append(Waiter(id: requestID, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(requestID: requestID) }
        }
    }

    func cancelWaiter(requestID: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == requestID }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    func release(requestID: UUID) {
        guard ownerID == requestID else { return }
        guard !waiters.isEmpty else {
            ownerID = nil
            return
        }
        let waiter = waiters.removeFirst()
        ownerID = waiter.id
        waiter.continuation.resume()
    }
}

private nonisolated enum CloudSynchronizationMutationContext {
    @TaskLocal static var ownedGateIDs: Set<UUID> = []
}
