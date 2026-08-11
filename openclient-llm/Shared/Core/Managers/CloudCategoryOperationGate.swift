//
//  CloudCategoryOperationGate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

actor CloudCategoryOperationGate {
    // MARK: - Properties

    static let shared = CloudCategoryOperationGate()

    private var isOccupied = false
    private var isFenceRequested = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Public

    func perform<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await acquireOperation()
        do {
            let value = try await operation()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }

    func fence<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        await acquireFence()
        do {
            let value = try await operation()
            isFenceRequested = false
            release()
            return value
        } catch {
            isFenceRequested = false
            release()
            throw error
        }
    }
}

// MARK: - Private

private extension CloudCategoryOperationGate {
    func acquireOperation() async throws {
        guard !isFenceRequested else { throw CloudSyncError.operationFenced }
        await acquire()
    }

    func acquireFence() async {
        isFenceRequested = true
        await acquire()
    }

    func acquire() async {
        guard isOccupied else {
            isOccupied = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isOccupied = false
            return
        }
        let waiter = waiters.removeFirst()
        waiter.resume()
    }
}
