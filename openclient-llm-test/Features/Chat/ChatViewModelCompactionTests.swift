//
//  ChatViewModelCompactionTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ChatViewModelCompactionTests: XCTestCase {
    func test_compaction_newMessageStarted_discardsStaleResult() async throws {
        // Given
        let fetchModels = MockFetchModelsUseCase()
        fetchModels.result = .success([LLMModel(id: "gpt-4", maxInputTokens: 1_024)])
        let stream = MockStreamMessageUseCase()
        stream.chunks = [.token("Answer")]
        let compaction = MockCompactConversationUseCase()
        compaction.shouldSuspend = true
        let sut = ChatViewModel(
            fetchModelsUseCase: fetchModels,
            streamMessageUseCase: stream,
            saveConversationUseCase: MockSaveConversationUseCase(),
            compactConversationUseCase: compaction
        )
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.inputChanged("First"))
        sut.send(.sendTapped)
        try await Task.sleep(for: .milliseconds(100))
        stream.tokenDelay = .milliseconds(250)
        sut.send(.inputChanged("Second"))

        // When
        sut.send(.sendTapped)
        compaction.result = CompactedConversation(summary: "Stale", cursorMessageId: UUID())
        compaction.resume()
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else { return XCTFail("Expected loaded state") }
        XCTAssertTrue(loadedState.messages.contains(where: { $0.content == "Second" }))
        XCTAssertNotEqual(loadedState.conversation?.contextSummary, "Stale")
        sut.send(.stopStreamingTapped)
    }
}
