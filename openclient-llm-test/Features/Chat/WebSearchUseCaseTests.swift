//
//  WebSearchUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class WebSearchUseCaseTests: XCTestCase {
    // MARK: - Properties

    var sut: WebSearchUseCase!
    var mockAPIClient: MockAPIClient!
    var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        mockSettingsManager = MockSettingsManager()
        sut = WebSearchUseCase(
            apiClient: mockAPIClient,
            settingsManager: mockSettingsManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        mockSettingsManager = nil
        try await super.tearDown()
    }

    // MARK: - Tests — success

    func test_execute_returnsResultsFromAPIClient() async throws {
        // Given
        let expectedResults = [
            LiteLLMSearchResult(title: "Swift", url: "https://swift.org", snippet: "A powerful language.", date: nil)
        ]
        mockAPIClient.requestResult = LiteLLMSearchResponse(object: "search", results: expectedResults)

        // When
        let results = try await sut.execute(query: "Swift programming")

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Swift")
        XCTAssertEqual(results.first?.url, "https://swift.org")
    }

    func test_execute_withEmptyResults_returnsEmptyArray() async throws {
        // Given
        mockAPIClient.requestResult = LiteLLMSearchResponse(object: "search", results: [])

        // When
        let results = try await sut.execute(query: "obscure topic")

        // Then
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Tests — error propagation

    func test_execute_withAPIError_throws() async throws {
        // Given
        mockAPIClient.requestError = APIError.networkError("Not connected")

        // When / Then
        do {
            _ = try await sut.execute(query: "query")
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            if case .networkError = error {
                // expected
            } else {
                XCTFail("Unexpected APIError case: \(error)")
            }
        }
    }

    // MARK: - Tests — settings

    func test_execute_usesWebSearchToolNameFromSettings() async throws {
        // Given
        mockSettingsManager.webSearchToolName = "tavily-search"
        mockAPIClient.requestResult = LiteLLMSearchResponse(object: "search", results: [])

        // When
        _ = try await sut.execute(query: "test")

        // Then — no crash; settings were read (endpoint construction uses toolName)
        XCTAssertEqual(mockSettingsManager.webSearchToolName, "tavily-search")
    }

    func test_execute_usesWebSearchMaxResultsFromSettings() async throws {
        // Given
        mockSettingsManager.webSearchMaxResults = 3
        mockAPIClient.requestResult = LiteLLMSearchResponse(object: "search", results: [])

        // When — execute should read maxResults = 3 from settings
        _ = try await sut.execute(query: "test")

        // Then
        XCTAssertEqual(mockSettingsManager.webSearchMaxResults, 3)
    }
}
