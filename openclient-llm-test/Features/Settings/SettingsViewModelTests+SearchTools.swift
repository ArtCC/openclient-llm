//
//  SettingsViewModelTests+SearchTools.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 25/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - fetchSearchToolsTapped

extension SettingsViewModelTests {
    func test_send_fetchSearchToolsTapped_success_populatesAvailableSearchTools() async throws {
        // Given
        let tools = [
            SearchToolItem(searchToolName: "brave-search", searchProvider: "brave", description: "Brave search"),
            SearchToolItem(
                searchToolName: "perplexity-search",
                searchProvider: "perplexity",
                description: "Perplexity search"
            )
        ]
        mockFetchSearchTools.result = .success(tools)
        sut.send(.viewAppeared)

        // When
        sut.send(.fetchSearchToolsTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.availableSearchTools.count, 2)
        XCTAssertEqual(loadedState.availableSearchTools[0].searchToolName, "brave-search")
        XCTAssertFalse(loadedState.isLoadingSearchTools)
        XCTAssertNil(loadedState.searchToolsError)
        XCTAssertEqual(mockFetchSearchTools.executeCallCount, 1)
    }

    func test_send_fetchSearchToolsTapped_failure_setsErrorMessage() async throws {
        // Given
        mockFetchSearchTools.result = .failure(APIError.networkError("Timeout"))
        sut.send(.viewAppeared)

        // When
        sut.send(.fetchSearchToolsTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedState.searchToolsError)
        XCTAssertFalse(loadedState.isLoadingSearchTools)
        XCTAssertTrue(loadedState.availableSearchTools.isEmpty)
    }

    func test_send_fetchSearchToolsTapped_autoSelectsFirstToolWhenCurrentNameNotInList() async throws {
        // Given — current saved name does not match any returned tool
        mockSettingsManager.webSearchToolName = "old-tool"
        let tools = [
            SearchToolItem(searchToolName: "new-brave", searchProvider: "brave", description: "Brave")
        ]
        mockFetchSearchTools.result = .success(tools)
        sut.send(.viewAppeared)

        // When
        sut.send(.fetchSearchToolsTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then — first tool is auto-selected and saved
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.webSearchToolName, "new-brave")
        XCTAssertEqual(mockSettingsManager.webSearchToolName, "new-brave")
    }

    func test_send_fetchSearchToolsTapped_doesNotAutoSelectWhenCurrentNameAlreadyValid() async throws {
        // Given — current saved name matches a returned tool
        mockSettingsManager.webSearchToolName = "brave-search"
        let tools = [
            SearchToolItem(searchToolName: "brave-search", searchProvider: "brave", description: "Brave"),
            SearchToolItem(searchToolName: "tavily", searchProvider: "tavily", description: "Tavily")
        ]
        mockFetchSearchTools.result = .success(tools)
        sut.send(.viewAppeared)

        // When
        sut.send(.fetchSearchToolsTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then — name unchanged
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.webSearchToolName, "brave-search")
    }

    func test_send_fetchSearchToolsTapped_success_persistsToolsToSettingsManager() async throws {
        // Given
        let tools = [
            SearchToolItem(searchToolName: "brave-search", searchProvider: "brave", description: "Brave")
        ]
        mockFetchSearchTools.result = .success(tools)
        sut.send(.viewAppeared)

        // When
        sut.send(.fetchSearchToolsTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then — tools are persisted in settings manager
        XCTAssertEqual(mockSettingsManager.availableSearchTools, tools)
    }

    func test_send_viewAppeared_restoresPersistedSearchTools() async throws {
        // Given — tools already persisted (simulating previous session)
        let tools = [
            SearchToolItem(searchToolName: "brave-search", searchProvider: "brave", description: "Brave"),
            SearchToolItem(searchToolName: "tavily", searchProvider: "tavily", description: "Tavily")
        ]
        mockSettingsManager.availableSearchTools = tools

        // When
        sut.send(.viewAppeared)

        // Then — tools are restored from settings manager without network call
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.availableSearchTools, tools)
        XCTAssertEqual(mockFetchSearchTools.executeCallCount, 0)
    }
}
