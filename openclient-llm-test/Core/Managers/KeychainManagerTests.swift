//
//  KeychainManagerTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class KeychainManagerTests: XCTestCase {
    // MARK: - Properties

    private var sut: KeychainManager!
    private let testService = "com.openclient-llm.tests"

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        sut = KeychainManager(service: testService)
        sut.deleteAll()
    }

    override func tearDown() async throws {
        sut.deleteAll()
        sut = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Server Base URL

    func test_getServerBaseURL_whenEmpty_returnsEmptyString() {
        // Then
        XCTAssertEqual(sut.getServerBaseURL(), "")
    }

    func test_setServerBaseURL_storesValue() {
        // When
        sut.setServerBaseURL("https://example.com")

        // Then
        XCTAssertEqual(sut.getServerBaseURL(), "https://example.com")
    }

    func test_setServerBaseURL_overwritesPreviousValue() {
        // Given
        sut.setServerBaseURL("https://old.com")

        // When
        sut.setServerBaseURL("https://new.com")

        // Then
        XCTAssertEqual(sut.getServerBaseURL(), "https://new.com")
    }

    // MARK: - Tests — API Key

    func test_getAPIKey_whenEmpty_returnsEmptyString() {
        // Then
        XCTAssertEqual(sut.getAPIKey(), "")
    }

    func test_setAPIKey_storesValue() {
        // When
        sut.setAPIKey("sk-test-key-123")

        // Then
        XCTAssertEqual(sut.getAPIKey(), "sk-test-key-123")
    }

    func test_setAPIKey_overwritesPreviousValue() {
        // Given
        sut.setAPIKey("sk-old-key")

        // When
        sut.setAPIKey("sk-new-key")

        // Then
        XCTAssertEqual(sut.getAPIKey(), "sk-new-key")
    }

    // MARK: - Tests — Delete All

    func test_deleteAll_removesAllStoredValues() {
        // Given
        sut.setServerBaseURL("https://example.com")
        sut.setAPIKey("sk-test-key")

        // When
        sut.deleteAll()

        // Then
        XCTAssertEqual(sut.getServerBaseURL(), "")
        XCTAssertEqual(sut.getAPIKey(), "")
    }

    // MARK: - Tests — Isolation

    func test_differentInstances_withSameService_shareData() {
        // Given
        sut.setAPIKey("shared-key")

        // When
        let otherInstance = KeychainManager(service: testService)

        // Then
        XCTAssertEqual(otherInstance.getAPIKey(), "shared-key")

        otherInstance.deleteAll()
    }

    func test_differentServices_doNotShareData() {
        // Given
        sut.setAPIKey("service-a-key")

        // When
        let otherService = KeychainManager(service: "com.openclient-llm.tests.other")

        // Then
        XCTAssertEqual(otherService.getAPIKey(), "")

        otherService.deleteAll()
    }
}
