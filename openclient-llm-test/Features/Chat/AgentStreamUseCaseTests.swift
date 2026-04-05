//
//  AgentStreamUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class AgentStreamUseCaseTests: XCTestCase {
    // MARK: - Properties

    var sut: AgentStreamUseCase!
    var mockRepository: MockChatRepository!
    var toolRegistry: ToolRegistry!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockChatRepository()
        sut = AgentStreamUseCase(repository: mockRepository)
        toolRegistry = ToolRegistry(tools: [])
    }

    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        toolRegistry = nil
        try await super.tearDown()
    }

    // MARK: - Tests — Single round (stop)

    func test_execute_stopOnFirstRound_emitsTokenAndCompletes() async throws {
        // Given
        mockRepository.agentCompletionResult = .success(makeStopResponse(content: "Hello world"))
        mockRepository.streamChunks = [.token("Hello"), .token(" world")]

        // When
        var tokens: [String] = []
        let stream = sut.execute(
            messages: [ChatMessage(role: .user, content: "Hi")],
            model: "gpt-4",
            parameters: .default,
            toolRegistry: toolRegistry
        )
        for try await event in stream {
            if case .token(let text) = event { tokens.append(text) }
        }

        // Then
        XCTAssertEqual(tokens, ["Hello", " world"])
    }

    // MARK: - Tests — Tool call round

    func test_execute_toolCallRoundThenStop_emitsToolEventsAndTokens() async throws {
        // Given
        let toolCall = ToolCall(
            id: "call_1",
            type: "function",
            function: ToolCallFunction(name: "unknown_tool", arguments: "{}")
        )
        let firstResponse = makeToolCallResponse(toolCalls: [toolCall])
        let secondResponse = makeStopResponse(content: "Based on results")
        let seqRepo = makeSequentialRepo(responses: [firstResponse, secondResponse])
        let seqSut = AgentStreamUseCase(repository: seqRepo)

        // When
        var toolStarted = false
        var toolCompleted = false
        var tokens: [String] = []
        let stream = seqSut.execute(
            messages: [ChatMessage(role: .user, content: "Search something")],
            model: "gpt-4",
            parameters: .default,
            toolRegistry: ToolRegistry(tools: [])
        )
        for try await event in stream {
            switch event {
            case .toolCallStarted: toolStarted = true
            case .toolCallCompleted: toolCompleted = true
            case .token(let text): tokens.append(text)
            default: break
            }
        }

        // Then
        XCTAssertTrue(toolStarted)
        XCTAssertTrue(toolCompleted)
        XCTAssertEqual(tokens, ["Based on results"])
        XCTAssertEqual(seqRepo.callIndex, 2)
    }

    // MARK: - Tests — Max iterations

    func test_execute_maxIterationsExceeded_stopsLoop() async throws {
        // Given — always returns tool_calls, never stop
        let toolCall = ToolCall(
            id: "call_1",
            type: "function",
            function: ToolCallFunction(name: "noop", arguments: "{}")
        )
        let toolCallResponse = makeToolCallResponse(toolCalls: [toolCall])

        final class InfiniteToolRepo: ChatRepositoryProtocol, @unchecked Sendable {
            var callCount = 0
            let toolCallResponse: ChatCompletionResponse

            init(response: ChatCompletionResponse) { self.toolCallResponse = response }

            func sendMessage(
                messages: [ChatMessage],
                model: String,
                parameters: ModelParameters
            ) async throws -> (String, TokenUsage?) { ("", nil) }

            func streamMessage(
                messages: [ChatMessage],
                model: String,
                parameters: ModelParameters
            ) -> AsyncThrowingStream<StreamChunk, Error> {
                AsyncThrowingStream { continuation in Task { continuation.finish() } }
            }

            func agentCompletion(
                messages: [ChatMessage],
                model: String,
                parameters: ModelParameters,
                tools: [ToolDefinition]
            ) async throws -> ChatCompletionResponse {
                callCount += 1
                return toolCallResponse
            }
        }

        let infiniteRepo = InfiniteToolRepo(response: toolCallResponse)
        let infiniteSut = AgentStreamUseCase(repository: infiniteRepo)

        // When — should not throw, should terminate
        var eventCount = 0
        let stream = infiniteSut.execute(
            messages: [ChatMessage(role: .user, content: "Loop")],
            model: "gpt-4",
            parameters: .default,
            toolRegistry: ToolRegistry(tools: [])
        )
        for try await _ in stream { eventCount += 1 }

        // Then — called max 10 times
        XCTAssertEqual(infiniteRepo.callCount, 10)
    }

    // MARK: - Tests — Network error

    func test_execute_networkError_propagatesError() async throws {
        // Given
        mockRepository.agentCompletionResult = .failure(APIError.networkError("Timeout"))

        // When / Then
        let stream = sut.execute(
            messages: [ChatMessage(role: .user, content: "Hi")],
            model: "gpt-4",
            parameters: .default,
            toolRegistry: toolRegistry
        )
        do {
            for try await _ in stream {}
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        }
    }
}

// MARK: - Helpers

private extension AgentStreamUseCaseTests {
    func makeStopResponse(content: String) -> ChatCompletionResponse {
        let message = ChatCompletionResponse.Message(
            role: "assistant", content: content, images: nil, toolCalls: nil
        )
        return ChatCompletionResponse(
            id: "resp-stop",
            choices: [ChatCompletionResponse.Choice(message: message, finishReason: "stop")],
            usage: nil
        )
    }

    func makeToolCallResponse(toolCalls: [ToolCall]) -> ChatCompletionResponse {
        let message = ChatCompletionResponse.Message(
            role: "assistant", content: nil, images: nil, toolCalls: toolCalls
        )
        return ChatCompletionResponse(
            id: "resp-tool",
            choices: [ChatCompletionResponse.Choice(message: message, finishReason: "tool_calls")],
            usage: nil
        )
    }

    func makeSequentialRepo(responses: [ChatCompletionResponse]) -> SequentialMockRepo {
        SequentialMockRepo(responses: responses)
    }
}

// MARK: - SequentialMockRepo

final class SequentialMockRepo: ChatRepositoryProtocol, @unchecked Sendable {
    var responses: [ChatCompletionResponse]
    var callIndex = 0
    let streamChunks: [StreamChunk] = [.token("Based on results")]

    init(responses: [ChatCompletionResponse]) {
        self.responses = responses
    }

    func sendMessage(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters
    ) async throws -> (String, TokenUsage?) { ("", nil) }

    func streamMessage(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        let chunks = streamChunks
        return AsyncThrowingStream { continuation in
            Task { for chunk in chunks { continuation.yield(chunk) }; continuation.finish() }
        }
    }

    func agentCompletion(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        tools: [ToolDefinition]
    ) async throws -> ChatCompletionResponse {
        let response = responses[callIndex]
        callIndex += 1
        return response
    }
}
