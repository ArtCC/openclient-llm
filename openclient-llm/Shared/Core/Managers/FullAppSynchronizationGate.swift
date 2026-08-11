//
//  FullAppSynchronizationGate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

actor FullAppSynchronizationGate {
    // MARK: - Properties

    static let shared = FullAppSynchronizationGate()

    private typealias Operation = @Sendable () async -> AppSynchronizationResult
    private typealias Waiter = CheckedContinuation<AppSynchronizationResult, Never>

    private struct QueuedBatch {
        var operation: Operation
        var waiters: [Waiter]
    }

    private var activeTask: Task<Void, Never>?
    private var activeWaiters: [Waiter] = []
    private var queuedBatch: QueuedBatch?
    private var generation = 0

    // MARK: - Public

    var pendingRequestCount: Int {
        queuedBatch?.waiters.count ?? 0
    }

    func perform(
        _ operation: @escaping @Sendable () async -> AppSynchronizationResult
    ) async -> AppSynchronizationResult {
        await withCheckedContinuation { continuation in
            enqueue(operation, waiter: continuation)
        }
    }

    func cancel() {
        generation += 1
        activeTask?.cancel()
        let waiters = activeWaiters + (queuedBatch?.waiters ?? [])
        activeWaiters = []
        queuedBatch = nil
        let result = AppSynchronizationResult(outcomes: [:])
        for waiter in waiters {
            waiter.resume(returning: result)
        }
    }
}

// MARK: - Private

private extension FullAppSynchronizationGate {
    private func enqueue(_ operation: @escaping Operation, waiter: Waiter) {
        guard activeTask != nil else {
            start(operation, waiters: [waiter])
            return
        }
        if queuedBatch == nil {
            queuedBatch = QueuedBatch(operation: operation, waiters: [waiter])
        } else {
            queuedBatch?.operation = operation
            queuedBatch?.waiters.append(waiter)
        }
    }

    private func start(_ operation: @escaping Operation, waiters: [Waiter]) {
        let runGeneration = generation
        activeWaiters = waiters
        activeTask = Task {
            let result = await operation()
            complete(result, generation: runGeneration)
        }
    }

    func complete(_ result: AppSynchronizationResult, generation runGeneration: Int) {
        guard runGeneration == generation else {
            activeTask = nil
            guard let queuedBatch else { return }
            self.queuedBatch = nil
            start(queuedBatch.operation, waiters: queuedBatch.waiters)
            return
        }
        activeTask = nil
        if let queuedBatch {
            self.queuedBatch = nil
            start(queuedBatch.operation, waiters: activeWaiters + queuedBatch.waiters)
            return
        }
        let waiters = activeWaiters
        activeWaiters = []
        for waiter in waiters { waiter.resume(returning: result) }
    }
}
