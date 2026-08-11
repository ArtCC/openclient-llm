//
//  CloudSynchronizationMutationGateTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudSynchronizationMutationGateTests: XCTestCase {
    func test_perform_overlappingOperations_runsOneAtATimeInFIFOOrder() async throws {
        // Given
        let sut = CloudSynchronizationMutationGate()
        let probe = MutationGateProbe()

        // When
        let first = Task {
            try await sut.perform { try await probe.execute(id: 1, waitsForRelease: true) }
        }
        await probe.waitForStartedCount(1)
        let second = Task { try await sut.perform { try await probe.execute(id: 2) } }
        let third = Task { try await sut.perform { try await probe.execute(id: 3) } }
        while await sut.pendingRequestCount < 2 { await Task.yield() }
        await probe.releaseBlockedExecution()
        _ = try await first.value
        _ = try await second.value
        _ = try await third.value

        // Then
        let order = await probe.startedOrder
        let maximumConcurrentExecutions = await probe.maximumConcurrentExecutions
        XCTAssertEqual(order, [1, 2, 3])
        XCTAssertEqual(maximumConcurrentExecutions, 1)
    }

    func test_perform_nestedAcquisition_executesWithoutDeadlock() async throws {
        // Given
        let sut = CloudSynchronizationMutationGate()

        // When
        let value = try await sut.perform {
            try await sut.perform { 42 }
        }

        // Then
        XCTAssertEqual(value, 42)
    }

    func test_perform_cancelledQueuedOperation_removesWaiterAndReleasesFollowingOperation() async throws {
        // Given
        let sut = CloudSynchronizationMutationGate()
        let probe = MutationGateProbe()
        let first = Task {
            try await sut.perform { try await probe.execute(id: 1, waitsForRelease: true) }
        }
        await probe.waitForStartedCount(1)
        let cancelled = Task { try await sut.perform { try await probe.execute(id: 2) } }
        let following = Task { try await sut.perform { try await probe.execute(id: 3) } }
        while await sut.pendingRequestCount < 2 { await Task.yield() }

        // When
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("Expected queued operation cancellation")
        } catch is CancellationError {
            // Expected.
        }
        await probe.releaseBlockedExecution()
        _ = try await first.value
        _ = try await following.value

        // Then
        let order = await probe.startedOrder
        let pendingRequestCount = await sut.pendingRequestCount
        XCTAssertEqual(order, [1, 3])
        XCTAssertEqual(pendingRequestCount, 0)
    }

    func test_perform_throwingOperation_releasesGate() async throws {
        // Given
        let sut = CloudSynchronizationMutationGate()

        // When
        do {
            _ = try await sut.perform { () async throws(MutationGateTestError) -> Int in
                throw .expected
            }
            XCTFail("Expected typed operation failure")
        } catch MutationGateTestError.expected {
            // Expected.
        }
        let value = try await sut.perform { "released" }

        // Then
        XCTAssertEqual(value, "released")
    }
}

private nonisolated enum MutationGateTestError: Error, Sendable {
    case expected
}

private actor MutationGateProbe {
    private(set) var startedOrder: [Int] = []
    private(set) var maximumConcurrentExecutions = 0
    private var activeExecutions = 0
    private var blockedContinuation: CheckedContinuation<Void, Never>?
    private var startedWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func execute(id: Int, waitsForRelease: Bool = false) async throws -> Int {
        try Task.checkCancellation()
        startedOrder.append(id)
        activeExecutions += 1
        maximumConcurrentExecutions = max(maximumConcurrentExecutions, activeExecutions)
        resumeStartedWaiters()
        if waitsForRelease {
            await withCheckedContinuation { blockedContinuation = $0 }
        }
        activeExecutions -= 1
        return id
    }

    func waitForStartedCount(_ count: Int) async {
        guard startedOrder.count < count else { return }
        await withCheckedContinuation { startedWaiters.append((count, $0)) }
    }

    func releaseBlockedExecution() {
        blockedContinuation?.resume()
        blockedContinuation = nil
    }

    private func resumeStartedWaiters() {
        let satisfied = startedWaiters.filter { startedOrder.count >= $0.0 }
        startedWaiters.removeAll { startedOrder.count >= $0.0 }
        for waiter in satisfied { waiter.1.resume() }
    }
}
