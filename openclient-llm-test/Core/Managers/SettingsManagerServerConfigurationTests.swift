//
//  SettingsManagerServerConfigurationTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 29/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SettingsManagerServerConfigurationTests: XCTestCase {
    // MARK: - Tests

    func test_hasValidServerConfiguration_emptyURL_returnsFalse() {
        // Given
        let sut = MockSettingsManager()

        // When
        let isValid = sut.hasValidServerConfiguration()

        // Then
        XCTAssertFalse(isValid)
    }

    func test_hasValidServerConfiguration_relativeURL_returnsFalse() {
        // Given
        let sut = MockSettingsManager()
        sut.serverBaseURL = "localhost:4000"

        // When
        let isValid = sut.hasValidServerConfiguration()

        // Then
        XCTAssertFalse(isValid)
    }

    func test_hasValidServerConfiguration_unsupportedScheme_returnsFalse() {
        // Given
        let sut = MockSettingsManager()
        sut.serverBaseURL = "ftp://example.com"

        // When
        let isValid = sut.hasValidServerConfiguration()

        // Then
        XCTAssertFalse(isValid)
    }

    func test_hasValidServerConfiguration_HTTPServer_returnsTrue() {
        // Given
        let sut = MockSettingsManager()
        sut.serverBaseURL = "http://localhost:4000/v1"

        // When
        let isValid = sut.hasValidServerConfiguration()

        // Then
        XCTAssertTrue(isValid)
    }

    func test_hasValidServerConfiguration_HTTPSServer_returnsTrue() {
        // Given
        let sut = MockSettingsManager()
        sut.serverBaseURL = "  https://example.com/v1  "

        // When
        let isValid = sut.hasValidServerConfiguration()

        // Then
        XCTAssertTrue(isValid)
    }
}
