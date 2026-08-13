//
//  FullAppSynchronizationGateTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class FullAppSynchronizationGateTests: XCTestCase {
    func test_perform_overlappingRequests_serializesAndCoalescesOneFollowUp() async {
        // Given
        let sut = FullAppSynchronizationGate()
        let probe = FullSyncProbe()

        // When
        let first = Task { await sut.perform { await probe.execute() } }
        await probe.waitForExecutionCount(1)
        let second = Task { await sut.perform { await probe.execute() } }
        let third = Task { await sut.perform { await probe.execute() } }
        while await sut.pendingRequestCount < 2 { await Task.yield() }
        await probe.resumeExecution()
        await probe.waitForExecutionCount(2)
        let maximumConcurrentExecutions = await probe.maximumConcurrentExecutions
        await probe.resumeExecution()
        _ = await first.value
        _ = await second.value
        _ = await third.value
        let executionCount = await probe.executionCount

        // Then
        XCTAssertEqual(executionCount, 2)
        XCTAssertEqual(maximumConcurrentExecutions, 1)
    }

    func test_perform_requestDuringFollowUp_runsOneAdditionalCoalescedFollowUp() async {
        // Given
        let sut = FullAppSynchronizationGate()
        let probe = FullSyncProbe()
        let first = Task { await sut.perform { await probe.execute() } }
        await probe.waitForExecutionCount(1)
        let second = Task { await sut.perform { await probe.execute() } }
        await probe.resumeExecution()
        await probe.waitForExecutionCount(2)

        // When
        let third = Task { await sut.perform { await probe.execute() } }
        let fourth = Task { await sut.perform { await probe.execute() } }
        while await sut.pendingRequestCount < 2 { await Task.yield() }
        await probe.resumeExecution()
        await probe.waitForExecutionCount(3)
        await probe.resumeExecution()
        _ = await first.value
        _ = await second.value
        _ = await third.value
        _ = await fourth.value
        let executionCount = await probe.executionCount
        let maximumConcurrentExecutions = await probe.maximumConcurrentExecutions

        // Then
        XCTAssertEqual(executionCount, 3)
        XCTAssertEqual(maximumConcurrentExecutions, 1)
    }

    func test_cancel_activeAndQueuedRequests_completesWaitersAndClearsQueue() async {
        // Given
        let sut = FullAppSynchronizationGate()
        let probe = FullSyncProbe()
        let first = Task { await sut.perform { await probe.executeUntilCancelled() } }
        await probe.waitForExecutionCount(1)
        let second = Task { await sut.perform { await probe.execute() } }
        while await sut.pendingRequestCount < 1 { await Task.yield() }

        // When
        await sut.cancel()
        _ = await first.value
        _ = await second.value
        await probe.waitForCancellation()
        let pendingRequestCount = await sut.pendingRequestCount
        let executionCount = await probe.executionCount
        let observedCancellation = await probe.observedCancellation

        // Then
        XCTAssertEqual(pendingRequestCount, 0)
        XCTAssertEqual(executionCount, 1)
        XCTAssertTrue(observedCancellation)
    }
}

private actor FullSyncProbe {
    private(set) var executionCount = 0
    private(set) var maximumConcurrentExecutions = 0
    private(set) var observedCancellation = false
    private var activeExecutions = 0
    private var executionContinuations: [CheckedContinuation<Void, Never>] = []
    private var countWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []

    func execute() async -> AppSynchronizationResult {
        executionCount += 1
        activeExecutions += 1
        maximumConcurrentExecutions = max(maximumConcurrentExecutions, activeExecutions)
        resumeSatisfiedWaiters()
        await withCheckedContinuation { continuation in
            executionContinuations.append(continuation)
        }
        activeExecutions -= 1
        return AppSynchronizationResult(outcomes: [:])
    }

    func executeUntilCancelled() async -> AppSynchronizationResult {
        executionCount += 1
        activeExecutions += 1
        maximumConcurrentExecutions = max(maximumConcurrentExecutions, activeExecutions)
        resumeSatisfiedWaiters()
        while !Task.isCancelled {
            await Task.yield()
        }
        observedCancellation = true
        for waiter in cancellationWaiters { waiter.resume() }
        cancellationWaiters = []
        activeExecutions -= 1
        return AppSynchronizationResult(outcomes: [:])
    }

    func waitForCancellation() async {
        guard !observedCancellation else { return }
        await withCheckedContinuation { cancellationWaiters.append($0) }
    }

    func waitForExecutionCount(_ count: Int) async {
        guard executionCount < count else { return }
        await withCheckedContinuation { continuation in
            countWaiters.append((count, continuation))
        }
    }

    func resumeExecution() {
        guard !executionContinuations.isEmpty else { return }
        executionContinuations.removeFirst().resume()
    }

    private func resumeSatisfiedWaiters() {
        let satisfied = countWaiters.filter { executionCount >= $0.0 }
        countWaiters.removeAll { executionCount >= $0.0 }
        for waiter in satisfied {
            waiter.1.resume()
        }
    }
}
