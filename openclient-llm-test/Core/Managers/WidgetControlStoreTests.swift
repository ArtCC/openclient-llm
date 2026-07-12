//
//  WidgetControlStoreTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class WidgetControlStoreTests: XCTestCase {
    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        clearPendingRequest()
    }

    override func tearDown() async throws {
        clearPendingRequest()
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_consumePendingNewChat_freshRequest_consumesItOnce() {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        WidgetControlStore.requestNewChat(now: now)

        // When
        let firstConsumption = WidgetControlStore.consumePendingNewChat(now: now.addingTimeInterval(60))
        let secondConsumption = WidgetControlStore.consumePendingNewChat(now: now.addingTimeInterval(60))

        // Then
        XCTAssertTrue(firstConsumption)
        XCTAssertFalse(secondConsumption)
    }

    func test_consumePendingNewChat_expiredRequest_discardsIt() {
        // Given
        let now = Date(timeIntervalSince1970: 1_000)
        WidgetControlStore.requestNewChat(now: now)

        // When
        let wasConsumed = WidgetControlStore.consumePendingNewChat(now: now.addingTimeInterval(301))

        // Then
        XCTAssertFalse(wasConsumed)
        XCTAssertNil(UserDefaults(suiteName: AppGroupStore.suiteName)?
            .object(forKey: WidgetControlStore.pendingNewChatRequestKey))
    }
}

// MARK: - Private

private extension WidgetControlStoreTests {
    func clearPendingRequest() {
        UserDefaults(suiteName: AppGroupStore.suiteName)?
            .removeObject(forKey: WidgetControlStore.pendingNewChatRequestKey)
    }
}
