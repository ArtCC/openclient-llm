//
//  TagColorTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class TagColorTests: XCTestCase {
    // MARK: - Tests — CaseIterable

    func test_allCases_hasExpectedCount() {
        XCTAssertEqual(TagColor.allCases.count, 10)
    }

    func test_allCases_containsRed() {
        XCTAssertTrue(TagColor.allCases.contains(.red))
    }

    // MARK: - Tests — id

    func test_id_equalsRawValue() {
        XCTAssertEqual(TagColor.red.id, "red")
        XCTAssertEqual(TagColor.blue.id, "blue")
    }

    // MARK: - Tests — Codable

    func test_codable_roundTrip_preservesValue() throws {
        // Given
        let color = TagColor.purple
        let data = try JSONEncoder().encode(color)

        // When
        let decoded = try JSONDecoder().decode(TagColor.self, from: data)

        // Then
        XCTAssertEqual(decoded, .purple)
    }

    func test_codable_allCases_roundTrip() throws {
        for color in TagColor.allCases {
            let data = try JSONEncoder().encode(color)
            let decoded = try JSONDecoder().decode(TagColor.self, from: data)
            XCTAssertEqual(decoded, color)
        }
    }

    func test_codable_unknownRawValue_fallsBackToOrange() throws {
        // Given
        let rawString = "\"invalid_color\""
        let jsonData = Data(rawString.utf8)

        // When
        let decoded = try JSONDecoder().decode(TagColor.self, from: jsonData)

        // Then
        XCTAssertEqual(decoded, .orange)
    }

    func test_codable_emptyRawValue_fallsBackToOrange() throws {
        // Given
        let rawString = "\"\""
        let jsonData = Data(rawString.utf8)

        // When
        let decoded = try JSONDecoder().decode(TagColor.self, from: jsonData)

        // Then
        XCTAssertEqual(decoded, .orange)
    }

    // MARK: - Tests — localizedName

    func test_localizedName_red_returnsNonEmpty() {
        XCTAssertFalse(TagColor.red.localizedName.isEmpty)
    }

    func test_localizedName_allCases_returnNonEmpty() {
        for color in TagColor.allCases {
            XCTAssertFalse(color.localizedName.isEmpty, "\(color) should have a localized name")
        }
    }
}
