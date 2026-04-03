//
//  ChatViewModelTests+Export.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Export conversation

@MainActor
extension ChatViewModelTests {
    // MARK: - exportConversation

    func test_send_exportConversation_withConversation_setsExportedData() async throws {
        // Given
        let expectedData = Data("{\"test\":true}".utf8)
        mockExportConversation.result = .success(expectedData)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hi")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // When
        sut.send(.exportConversation)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.exportedData, expectedData)
        XCTAssertFalse(mockExportConversation.executedConversations.isEmpty)
    }

    func test_send_exportConversation_withoutConversation_doesNotSetExportedData() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When (no conversation started)
        sut.send(.exportConversation)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.exportedData)
        XCTAssertTrue(mockExportConversation.executedConversations.isEmpty)
    }

    func test_send_exportConversation_onError_setsErrorMessage() async throws {
        // Given
        mockExportConversation.result = .failure(APIError.decodingError)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hi")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        // When
        sut.send(.exportConversation)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.exportedData)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    // MARK: - exportDataConsumed

    func test_send_exportDataConsumed_clearsExportedData() async throws {
        // Given
        let expectedData = Data("{\"test\":true}".utf8)
        mockExportConversation.result = .success(expectedData)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockStreamMessage.chunks = [.token("Hi")]
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.inputChanged("Hello"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(200))

        sut.send(.exportConversation)

        guard case .loaded(let loadedBefore) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedBefore.exportedData)

        // When
        sut.send(.exportDataConsumed)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.exportedData)
    }
}
