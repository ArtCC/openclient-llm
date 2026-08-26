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
    func test_send_firstOverflow_compactsAndPersistsBeforeRegularRequest() async throws {
        // Given
        let model = LLMModel(id: "gpt-4", maxInputTokens: 1_024)
        let history = overflowingHistory()
        let conversation = Conversation(modelId: model.id, messages: history)
        let stream = MockStreamMessageUseCase()
        stream.chunks = [.token("Answer")]
        let compaction = MockCompactConversationUseCase()
        compaction.results = [
            CompactedConversation(summary: "Earlier facts", cursorMessageId: history[1].id),
            nil
        ]
        let save = MockSaveConversationUseCase()
        let requestStarted = expectation(description: "Regular request started")
        stream.onExecute = {
            compaction.results = []
            compaction.result = nil
            requestStarted.fulfill()
        }
        let sut = makeViewModel(
            model: model,
            conversation: conversation,
            streamMessageUseCase: stream,
            saveConversationUseCase: save,
            compactConversationUseCase: compaction
        )
        sut.send(.inputChanged("Latest question"))

        // When
        sut.send(.sendTapped)
        await fulfillment(of: [requestStarted], timeout: 1)

        // Then
        let sentMessages = try XCTUnwrap(stream.receivedMessages.first)
        XCTAssertTrue(sentMessages.first?.content.contains("Earlier facts") == true)
        XCTAssertFalse(sentMessages.contains(where: { $0.id == history[0].id }))
        XCTAssertFalse(sentMessages.contains(where: { $0.id == history[1].id }))
        XCTAssertTrue(sentMessages.contains(where: { $0.content == "Latest question" }))
        XCTAssertTrue(save.savedConversations.contains {
            $0.contextSummary == "Earlier facts" && $0.contextSummaryCursorMessageId == history[1].id
        })
        sut.send(.stopStreamingTapped)
    }

    func test_send_firstAgentOverflow_compactsBeforeAgentRequest() async throws {
        // Given
        let model = LLMModel(id: "gpt-4", capabilities: [.functionCalling], maxInputTokens: 3_000)
        let history = overflowingHistory(turnCount: 4, userCharacters: 2_500, assistantCharacters: 400)
        let conversation = Conversation(modelId: model.id, messages: history)
        let agent = MockAgentStreamUseCase()
        agent.events = [.token("Agent answer")]
        let compaction = MockCompactConversationUseCase()
        compaction.results = stride(from: 1, through: history.count - 1, by: 2).map { index -> CompactedConversation? in
            CompactedConversation(
                summary: "Summary through turn \((index + 1) / 2)",
                cursorMessageId: history[index].id
            )
        }
        let save = MockSaveConversationUseCase()
        let requestStarted = expectation(description: "Agent request started")
        agent.onExecute = {
            compaction.results = []
            compaction.result = nil
            requestStarted.fulfill()
        }
        let sut = makeViewModel(
            model: model,
            conversation: conversation,
            agentStreamUseCase: agent,
            saveConversationUseCase: save,
            compactConversationUseCase: compaction
        )
        sut.send(.inputChanged("Latest agent question"))

        // When
        sut.send(.sendTapped)
        await fulfillment(of: [requestStarted], timeout: 1)

        // Then
        let sentMessages = try XCTUnwrap(agent.receivedMessages.first)
        XCTAssertTrue(sentMessages.first?.content.contains("Conversation summary from earlier messages") == true)
        XCTAssertFalse(sentMessages.contains(where: { $0.id == history[0].id }))
        XCTAssertTrue(sentMessages.contains(where: { $0.content == "Latest agent question" }))
        XCTAssertTrue(save.savedConversations.contains { $0.contextSummary != nil })
        sut.send(.stopStreamingTapped)
    }

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
            fetchMCPToolsUseCase: MockFetchMCPToolsUseCase(),
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

private extension ChatViewModelCompactionTests {
    func makeViewModel(
        model: LLMModel,
        conversation: Conversation,
        streamMessageUseCase: StreamMessageUseCaseProtocol = MockStreamMessageUseCase(),
        agentStreamUseCase: AgentStreamUseCaseProtocol = MockAgentStreamUseCase(),
        saveConversationUseCase: SaveConversationUseCaseProtocol,
        compactConversationUseCase: CompactConversationUseCaseProtocol
    ) -> ChatViewModel {
        ChatViewModel(
            state: .loaded(.init(
                conversation: conversation,
                messages: conversation.messages,
                selectedModel: model,
                availableModels: [model]
            )),
            streamMessageUseCase: streamMessageUseCase,
            agentStreamUseCase: agentStreamUseCase,
            saveConversationUseCase: saveConversationUseCase,
            fetchMCPToolsUseCase: MockFetchMCPToolsUseCase(),
            getUserProfileContextUseCase: MockGetUserProfileContextUseCase(),
            getMemoryContextUseCase: MockGetMemoryContextUseCase(),
            compactConversationUseCase: compactConversationUseCase
        )
    }

    func overflowingHistory(
        turnCount: Int = 2,
        userCharacters: Int = 1_100,
        assistantCharacters: Int = 400
    ) -> [ChatMessage] {
        (0..<turnCount).flatMap { index in
            [
                ChatMessage(role: .user, content: "User \(index) " + String(repeating: "u", count: userCharacters)),
                ChatMessage(
                    role: .assistant,
                    content: "Assistant \(index) " + String(repeating: "a", count: assistantCharacters)
                )
            ]
        }
    }
}
