//
//  ModelParametersTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ModelParametersTests: XCTestCase {
    // MARK: - Tests — default

    func test_default_hasNoCustomValues() {
        XCTAssertFalse(ModelParameters.default.hasCustomValues)
    }

    func test_default_allPropertiesAreNil() {
        XCTAssertNil(ModelParameters.default.temperature)
        XCTAssertNil(ModelParameters.default.maxTokens)
        XCTAssertNil(ModelParameters.default.topP)
    }

    // MARK: - Tests — hasCustomValues

    func test_hasCustomValues_withTemperature_returnsTrue() {
        // Given
        let params = ModelParameters(temperature: 0.7)

        // Then
        XCTAssertTrue(params.hasCustomValues)
    }

    func test_hasCustomValues_withMaxTokens_returnsTrue() {
        // Given
        let params = ModelParameters(maxTokens: 2048)

        // Then
        XCTAssertTrue(params.hasCustomValues)
    }

    func test_hasCustomValues_withTopP_returnsTrue() {
        // Given
        let params = ModelParameters(topP: 0.9)

        // Then
        XCTAssertTrue(params.hasCustomValues)
    }

    func test_hasCustomValues_withMultipleParams_returnsTrue() {
        // Given
        let params = ModelParameters(temperature: 0.5, maxTokens: 1024)

        // Then
        XCTAssertTrue(params.hasCustomValues)
    }

    func test_hasCustomValues_emptyInit_returnsFalse() {
        // Given
        let params = ModelParameters()

        // Then
        XCTAssertFalse(params.hasCustomValues)
    }

    // MARK: - Tests — Equatable

    func test_equatable_sameValues_areEqual() {
        let paramsA = ModelParameters(temperature: 0.7)
        let paramsB = ModelParameters(temperature: 0.7)
        XCTAssertEqual(paramsA, paramsB)
    }

    func test_equatable_differentValues_areNotEqual() {
        let paramsA = ModelParameters(temperature: 0.7)
        let paramsB = ModelParameters(temperature: 0.8)
        XCTAssertNotEqual(paramsA, paramsB)
    }

    // MARK: - Tests — Codable

    func test_codable_roundTrip_preservesValues() throws {
        // Given
        let params = ModelParameters(temperature: 0.7, maxTokens: 2048, topP: 0.9)
        let data = try JSONEncoder().encode(params)

        // When
        let decoded = try JSONDecoder().decode(ModelParameters.self, from: data)

        // Then
        XCTAssertEqual(decoded.temperature, 0.7)
        XCTAssertEqual(decoded.maxTokens, 2048)
        XCTAssertEqual(decoded.topP, 0.9)
    }

    func test_codable_allNilRoundTrip() throws {
        // Given
        let params = ModelParameters()
        let data = try JSONEncoder().encode(params)

        // When
        let decoded = try JSONDecoder().decode(ModelParameters.self, from: data)

        // Then
        XCTAssertNil(decoded.temperature)
        XCTAssertNil(decoded.maxTokens)
        XCTAssertNil(decoded.topP)
    }
}
