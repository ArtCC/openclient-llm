//
//  NotifyStreamingCompletedUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 27/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class NotifyStreamingCompletedUseCaseTests: XCTestCase {
    func test_execute_applicationInBackground_sendsCompletionNotification() {
        // Given
        let manager = MockLocalNotificationManager()
        let sut = NotifyStreamingCompletedUseCase(
            localNotificationManager: manager,
            isApplicationInBackground: { true }
        )

        // When
        sut.execute()

        // Then
        XCTAssertEqual(manager.completionCallCount, 1)
    }

    func test_execute_applicationInForeground_doesNotSendNotification() {
        // Given
        let manager = MockLocalNotificationManager()
        let sut = NotifyStreamingCompletedUseCase(
            localNotificationManager: manager,
            isApplicationInBackground: { false }
        )

        // When
        sut.execute()

        // Then
        XCTAssertEqual(manager.completionCallCount, 0)
    }

    func test_executeExpired_sendsNotificationRegardlessOfApplicationState() {
        // Given
        let manager = MockLocalNotificationManager()
        let sut = NotifyStreamingCompletedUseCase(
            localNotificationManager: manager,
            isApplicationInBackground: { false }
        )

        // When
        sut.executeExpired()

        // Then
        XCTAssertEqual(manager.expirationCallCount, 1)
    }
}
