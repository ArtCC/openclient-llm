//
//  GetCurrentDatetimeToolTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class GetCurrentDatetimeToolTests: XCTestCase {
    // MARK: - Properties

    private var sut: GetCurrentDatetimeTool!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        sut = GetCurrentDatetimeTool()
    }

    override func tearDown() async throws {
        sut = nil

        try await super.tearDown()
    }

    // MARK: - Tests — definition

    func test_definition_hasCorrectName() {
        XCTAssertEqual(sut.definition.function.name, "get_current_datetime")
    }

    func test_definition_hasNoRequiredParameters() {
        XCTAssertTrue(sut.definition.function.parameters.required.isEmpty)
    }

    func test_definition_hasEmptyProperties() {
        XCTAssertTrue(sut.definition.function.parameters.properties.isEmpty)
    }

    // MARK: - Tests — execute

    func test_execute_returnsNonEmptyString() async throws {
        // When
        let result = try await sut.execute(arguments: "{}")

        // Then
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_execute_containsTimeZoneIdentifier() async throws {
        // When
        let result = try await sut.execute(arguments: "{}")

        // Then
        let timeZoneID = TimeZone.current.identifier
        XCTAssertTrue(result.text.contains(timeZoneID))
    }

    func test_execute_returnsDateTimeFormat() async throws {
        // When
        let result = try await sut.execute(arguments: "{}")

        // Then
        let containsDatePattern = result.text.contains(",")
        let containsTimePattern = result.text.contains(":")
        XCTAssertTrue(containsDatePattern)
        XCTAssertTrue(containsTimePattern)
    }
}
