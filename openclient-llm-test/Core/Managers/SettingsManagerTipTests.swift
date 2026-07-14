//
//  SettingsManagerTipTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SettingsManagerTipTests: XCTestCase {
    // MARK: - Properties

    private var sut: SettingsManager!
    private var mockKeychain: MockKeychainManager!
    private let suiteName = "com.artcc.openclient-llm.test.tips"

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        UserDefaults().removePersistentDomain(forName: suiteName)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test UserDefaults")
            return
        }
        mockKeychain = MockKeychainManager()
        sut = SettingsManager(defaults: defaults, keychainManager: mockKeychain)
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: suiteName)
        sut = nil
        mockKeychain = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_getHasEnoughConversationsForMemoryTip_defaultValue_returnsFalse() {
        // When
        let value = sut.getHasEnoughConversationsForMemoryTip()

        // Then
        XCTAssertFalse(value)
    }

    func test_setHasEnoughConversationsForMemoryTip_true_persistsValue() {
        // When
        sut.setHasEnoughConversationsForMemoryTip(true)

        // Then
        XCTAssertTrue(sut.getHasEnoughConversationsForMemoryTip())
    }

    func test_deleteAll_withMemoryTipEligibility_clearsValue() {
        // Given
        sut.setHasEnoughConversationsForMemoryTip(true)

        // When
        sut.deleteAll()

        // Then
        XCTAssertFalse(sut.getHasEnoughConversationsForMemoryTip())
    }
}
