//
//  ChatViewModelTests+WebSearch.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Web Search

@MainActor
extension ChatViewModelTests {
    func test_send_webSearchToggled_flipsIsWebSearchEnabled() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        guard case .loaded(let before) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(before.isWebSearchEnabled)

        // When
        sut.send(.webSearchToggled)

        // Then
        guard case .loaded(let after) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(after.isWebSearchEnabled)
    }

    func test_send_webSearchToggled_twice_returnsFalse() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.webSearchToggled)
        sut.send(.webSearchToggled)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isWebSearchEnabled)
    }

    func test_send_sendTapped_withWebSearchEnabled_callsWebSearch() async throws {
        // Given
        let searchResults = [
            LiteLLMSearchResult(
                title: "Swift 6",
                url: "https://swift.org",
                snippet: "Swift 6 introduces strict concurrency.",
                date: nil
            )
        ]
        mockWebSearch.result = .success(searchResults)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Answer about Swift 6.")]

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.webSearchToggled)
        sut.send(.inputChanged("Tell me about Swift 6"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(300))

        // Then
        XCTAssertEqual(mockWebSearch.executeCallCount, 1)
        XCTAssertEqual(mockWebSearch.lastQuery, "Tell me about Swift 6")

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertEqual(assistantMessage?.role, .assistant)
        XCTAssertEqual(assistantMessage?.webSearchResults?.count, 1)
        XCTAssertEqual(assistantMessage?.webSearchResults?.first?.title, "Swift 6")
    }

    func test_send_sendTapped_withWebSearchDisabled_doesNotCallWebSearch() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hello")]

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Web search is disabled by default
        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        XCTAssertEqual(mockWebSearch.executeCallCount, 0)

        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertNil(assistantMessage?.webSearchResults)
    }

    func test_send_sendTapped_withWebSearchFailing_fallsBackGracefully() async throws {
        // Given
        mockWebSearch.result = .failure(URLError(.notConnectedToInternet))
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Fallback answer.")]

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.webSearchToggled)
        sut.send(.inputChanged("What is the weather?"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(300))

        // Then: streaming proceeds despite search failure
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        let assistantMessage = loadedState.messages.last
        XCTAssertEqual(assistantMessage?.content, "Fallback answer.")
        XCTAssertNil(assistantMessage?.webSearchResults)
        XCTAssertFalse(loadedState.isStreaming)
    }

    func test_buildWebSearchContext_returnsMarkdownWithTopFiveResults() {
        // Given
        let results = (1...7).map {
            LiteLLMSearchResult(
                title: "Result \($0)",
                url: "https://example.com/\($0)",
                snippet: "Snippet \($0)",
                date: nil
            )
        }

        // When
        let context = sut.buildWebSearchContext(results: results)

        // Then — only top 5 results should appear
        XCTAssertTrue(context.contains("Result 1"))
        XCTAssertTrue(context.contains("Result 5"))
        XCTAssertFalse(context.contains("Result 6"))
        XCTAssertFalse(context.contains("Result 7"))
    }

    func test_buildWebSearchContext_withEmptyResults_returnsEmptyString() {
        // When
        let context = sut.buildWebSearchContext(results: [])

        // Then
        XCTAssertEqual(context, "")
    }
}
