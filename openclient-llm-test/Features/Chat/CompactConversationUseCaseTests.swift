//
//  CompactConversationUseCaseTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CompactConversationUseCaseTests: XCTestCase {
    // MARK: - Tests

    func test_execute_historyExceedsContext_returnsPersistableSummary() async throws {
        // Given
        let repository = MockChatRepository()
        repository.sendMessageResult = .success(("A concise summary", nil))
        let sut = CompactConversationUseCase(repository: repository)
        let messages = makeMessages(count: 5, characters: 600)

        // When
        let summary = try await sut.execute(messages: messages, configuration: configuration())

        // Then
        XCTAssertEqual(summary?.summary, "A concise summary")
        XCTAssertEqual(summary?.cursorMessageId, messages.first?.id)
    }

    func test_execute_historyFitsContext_returnsNilWithoutCompletion() async throws {
        // Given
        let repository = MockChatRepository()
        let sut = CompactConversationUseCase(repository: repository)

        // When
        let summary = try await sut.execute(
            messages: [ChatMessage(role: .user, content: "Hello")],
            configuration: configuration(contextWindowTokens: 16_000)
        )

        // Then
        XCTAssertNil(summary)
    }

    func test_execute_afterCursor_summarizesOnlyNewlyExcludedMessages() async throws {
        // Given
        let repository = MockChatRepository()
        repository.sendMessageResult = .success(("Updated summary", nil))
        let sut = CompactConversationUseCase(repository: repository)
        let summarized = ChatMessage(role: .user, content: String(repeating: "a", count: 100))
        let newMessages = makeMessages(count: 5, characters: 600)

        // When
        let summary = try await sut.execute(
            messages: [summarized] + newMessages,
            configuration: configuration(existingSummary: "Earlier summary", cursorMessageId: summarized.id)
        )

        // Then
        XCTAssertEqual(summary?.cursorMessageId, newMessages.first?.id)
    }

    func test_execute_modelOutputLimitBelowDefault_capsSummaryRequest() async throws {
        // Given
        let repository = RecordingChatRepository()
        let sut = CompactConversationUseCase(repository: repository)
        let messages = makeMessages(count: 5, characters: 600)

        // When
        _ = try await sut.execute(
            messages: messages,
            configuration: configuration(maxOutputTokens: 32)
        )

        // Then
        XCTAssertEqual(repository.lastParameters?.maxTokens, 32)
    }

    func configuration(
        existingSummary: String? = nil,
        cursorMessageId: UUID? = nil,
        contextWindowTokens: Int? = 1_024,
        maxOutputTokens: Int? = nil,
        systemPrompt: String = "",
        tools: [ToolDefinition] = []
    ) -> CompactionConfiguration {
        CompactionConfiguration(
            existingSummary: existingSummary,
            summaryCursorMessageId: cursorMessageId,
            model: "test",
            contextWindowTokens: contextWindowTokens,
            maxOutputTokens: maxOutputTokens,
            systemPrompt: systemPrompt,
            tools: tools
        )
    }

    func makeMessages(count: Int, characters: Int) -> [ChatMessage] {
        (0..<count).map { index in
            ChatMessage(role: .user, content: "\(index)" + String(repeating: "a", count: characters))
        }
    }

    func test_execute_sourceLargerThanOneSummaryRequest_advancesOnlyThroughSentMessages() async throws {
        // Given
        let repository = RecordingChatRepository()
        let sut = CompactConversationUseCase(repository: repository)
        let messages = makeMessages(count: 8, characters: 600)

        // When
        let compacted = try await sut.execute(messages: messages, configuration: configuration())

        // Then
        let sentSource = Array(repository.lastMessages.dropFirst())
        XCTAssertFalse(sentSource.isEmpty)
        XCTAssertLessThan(sentSource.count, messages.count)
        XCTAssertEqual(compacted?.cursorMessageId, sentSource.last?.id)
    }

    func test_execute_systemPromptCausesOverflow_compactsExcludedMessages() async throws {
        // Given
        let repository = RecordingChatRepository()
        let sut = CompactConversationUseCase(repository: repository)
        let messages = makeMessages(count: 4, characters: 150)

        // When
        let result = try await sut.execute(
            messages: messages,
            configuration: configuration(systemPrompt: String(repeating: "s", count: 2_100))
        )

        // Then
        XCTAssertNotNil(result)
        XCTAssertFalse(repository.lastMessages.isEmpty)
    }

    func test_execute_singleOversizedTurn_summarizesAllChunksBeforeAdvancingCursor() async throws {
        // Given
        let repository = RecordingChatRepository()
        let sut = CompactConversationUseCase(repository: repository)
        let message = ChatMessage(role: .user, content: String(repeating: "a", count: 5_000))

        // When
        let result = try await sut.execute(messages: [message], configuration: configuration())

        // Then
        XCTAssertGreaterThan(repository.requests.count, 1)
        XCTAssertEqual(result?.cursorMessageId, message.id)
    }
}

// MARK: - RecordingChatRepository

private final class RecordingChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    // Safety: Only used within serialized @MainActor test methods.

    var lastParameters: ModelParameters?
    var lastMessages: [ChatMessage] = []
    var requests: [[ChatMessage]] = []

    func sendMessage(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters
    ) async throws -> (String, TokenUsage?) {
        lastMessages = messages
        requests.append(messages)
        lastParameters = parameters
        return ("Summary", nil)
    }

    func streamMessage(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func agentCompletion(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        tools: [ToolDefinition]?
    ) async throws -> ChatCompletionResponse {
        throw APIError.networkError("Not configured")
    }
}
