//
//  WebSearchToolTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class WebSearchToolTests: XCTestCase {
    // MARK: - Properties

    private var sut: WebSearchTool!
    private var mockWebSearchUseCase: MockWebSearchUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockWebSearchUseCase = MockWebSearchUseCase()
        sut = WebSearchTool(webSearchUseCase: mockWebSearchUseCase)
    }

    override func tearDown() async throws {
        sut = nil
        mockWebSearchUseCase = nil

        try await super.tearDown()
    }

    // MARK: - Tests — definition

    func test_definition_hasCorrectName() {
        XCTAssertEqual(sut.definition.function.name, "web_search")
    }

    func test_definition_hasQueryParameter() {
        XCTAssertNotNil(sut.definition.function.parameters.properties["query"])
        XCTAssertTrue(sut.definition.function.parameters.required.contains("query"))
    }

    // MARK: - Tests — execute with invalid input

    func test_execute_withInvalidJSON_returnsErrorMessage() async throws {
        // Given
        let arguments = "not-json"

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockWebSearchUseCase.executeCallCount, 0)
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_execute_withEmptyQuery_returnsErrorMessage() async throws {
        // Given
        let arguments = #"{"query": ""}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockWebSearchUseCase.executeCallCount, 0)
        XCTAssertFalse(result.text.isEmpty)
    }

    func test_execute_withMissingQuery_returnsErrorMessage() async throws {
        // Given
        let arguments = #"{"other": "value"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockWebSearchUseCase.executeCallCount, 0)
        XCTAssertFalse(result.text.isEmpty)
    }

    // MARK: - Tests — execute with valid input

    func test_execute_withValidQuery_delegatesToWebSearchUseCase() async throws {
        // Given
        let searchResults = [
            LiteLLMSearchResult(title: "Result 1", url: "https://example.com/1", snippet: "Snippet 1", date: nil)
        ]
        mockWebSearchUseCase.result = .success(searchResults)
        let arguments = #"{"query": "Swift programming"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockWebSearchUseCase.executeCallCount, 1)
        XCTAssertEqual(mockWebSearchUseCase.lastQuery, "Swift programming")
        XCTAssertTrue(result.text.contains("Result 1"))
        XCTAssertTrue(result.text.contains("https://example.com/1"))
    }

    func test_execute_withEmptyResults_returnsNonEmptyMessage() async throws {
        // Given
        mockWebSearchUseCase.result = .success([])
        let arguments = #"{"query": "no results query"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertEqual(mockWebSearchUseCase.executeCallCount, 1)
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertNil(result.searchResults)
    }

    func test_execute_includesSearchResultsInOutput() async throws {
        // Given
        let results = [
            LiteLLMSearchResult(title: "Title A", url: "https://a.com", snippet: "Snippet A", date: nil),
            LiteLLMSearchResult(title: "Title B", url: "https://b.com", snippet: "Snippet B", date: nil),
        ]
        mockWebSearchUseCase.result = .success(results)
        let arguments = #"{"query": "test"}"#

        // When
        let result = try await sut.execute(arguments: arguments)

        // Then
        XCTAssertTrue(result.text.contains("Title A"))
        XCTAssertTrue(result.text.contains("Title B"))
        XCTAssertNotNil(result.searchResults)
        XCTAssertEqual(result.searchResults?.count, 2)
    }
}
