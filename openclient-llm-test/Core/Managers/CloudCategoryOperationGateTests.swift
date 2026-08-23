//
//  CloudCategoryOperationGateTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 22/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudCategoryOperationGateTests: XCTestCase {
    // MARK: - Tests

    func test_perform_cancelledBeforeAcquisition_doesNotExecuteOperation() async throws {
        // Given
        let sut = CloudCategoryOperationGate()
        let firstOperationStarted = TestAsyncGate()
        let releaseFirstOperation = TestAsyncGate()
        let firstTask = Task {
            try await sut.perform {
                await firstOperationStarted.open()
                await releaseFirstOperation.wait()
            }
        }
        await firstOperationStarted.wait()
        let cancelledTask = Task { () -> (any Error)? in
            do {
                try await sut.perform {}
                return nil
            } catch {
                return error
            }
        }

        // When
        cancelledTask.cancel()
        await releaseFirstOperation.open()

        // Then
        let cancellationError = await cancelledTask.value
        try await firstTask.value
        let remainedUsable = try await sut.perform { true }
        XCTAssertTrue(cancellationError is CancellationError)
        XCTAssertTrue(remainedUsable)
    }

    func test_fence_cancelledBeforeAcquisition_doesNotExecuteOperation() async throws {
        // Given
        let sut = CloudCategoryOperationGate()
        let firstOperationStarted = TestAsyncGate()
        let releaseFirstOperation = TestAsyncGate()
        let firstTask = Task {
            try await sut.perform {
                await firstOperationStarted.open()
                await releaseFirstOperation.wait()
            }
        }
        await firstOperationStarted.wait()
        let cancelledTask = Task { () -> (any Error)? in
            do {
                try await sut.fence {}
                return nil
            } catch {
                return error
            }
        }

        // When
        cancelledTask.cancel()
        await releaseFirstOperation.open()

        // Then
        let cancellationError = await cancelledTask.value
        try await firstTask.value
        let remainedUsable = try await sut.perform { true }
        XCTAssertTrue(cancellationError is CancellationError)
        XCTAssertTrue(remainedUsable)
    }
}
