//
//  AgentStreamUseCaseContextTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class AgentStreamUseCaseContextTests: XCTestCase {
    func test_execute_twoToolRounds_keepsToolsEnabledAndPersistsTranscript() async throws {
        // Given
        let calls = [makeToolCall(id: "call_1"), makeToolCall(id: "call_2")]
        let repository = RecordingAgentRepository(responses: [
            makeToolCallResponse(calls[0]),
            makeToolCallResponse(calls[1]),
            makeStopResponse(content: "Final answer")
        ])
        let sut = AgentStreamUseCase(repository: repository)

        // When
        var transcript: [ChatMessage] = []
        for try await event in sut.execute(
            messages: [ChatMessage(role: .user, content: "What time is it?")],
            model: "test",
            parameters: .default,
            toolRegistry: ToolRegistry(tools: [GetCurrentDatetimeTool()])
        ) {
            if case .transcriptAppended(let messages) = event { transcript.append(contentsOf: messages) }
        }

        // Then
        XCTAssertEqual(repository.requests.count, 3)
        XCTAssertTrue(repository.toolRequests.allSatisfy { $0?.isEmpty == false })
        XCTAssertEqual(transcript.map(\.role), [.assistant, .tool, .assistant, .tool])
    }

    func test_execute_multipleResponses_emitsCumulativeUsage() async throws {
        // Given
        let firstUsage = TokenUsage(promptTokens: 10, completionTokens: 2, totalTokens: 12)
        let secondUsage = TokenUsage(promptTokens: 20, completionTokens: 3, totalTokens: 23)
        let first = response(makeToolCallResponse(makeToolCall(id: "call_1")), usage: firstUsage)
        let second = response(makeStopResponse(content: "Done"), usage: secondUsage)
        let repository = RecordingAgentRepository(responses: [first, second])
        let sut = AgentStreamUseCase(repository: repository)

        // When
        var usages: [TokenUsage] = []
        for try await event in sut.execute(
            messages: [ChatMessage(role: .user, content: "Time")],
            model: "test",
            parameters: .default,
            toolRegistry: ToolRegistry(tools: [GetCurrentDatetimeTool()])
        ) {
            if case .usage(let usage) = event { usages.append(usage) }
        }

        // Then
        XCTAssertEqual(usages.last, TokenUsage(promptTokens: 30, completionTokens: 5, totalTokens: 35))
    }

    func test_execute_timeout_finishesEvenWhenRequestIsStillRunning() async throws {
        // Given
        let repository = MockChatRepository()
        repository.agentCompletionResult = .success(makeStopResponse(content: "Late"))
        repository.agentCompletionDelay = .seconds(1)
        let sut = AgentStreamUseCase(repository: repository, timeout: .milliseconds(10))

        // When / Then
        do {
            for try await _ in sut.execute(
                messages: [ChatMessage(role: .user, content: "Hello")],
                model: "test",
                parameters: .default,
                toolRegistry: ToolRegistry(tools: [])
            ) {}
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(error as? AgentStreamError, .timedOut)
        }
    }

    func test_execute_duplicateToolCallIdentifiers_throwsInvalidResponse() async throws {
        // Given
        let call = makeToolCall(id: "duplicate")
        let message = ChatCompletionResponse.Message(
            role: "assistant", content: nil, reasoningContent: nil, images: nil, toolCalls: [call, call]
        )
        let response = ChatCompletionResponse(
            id: "duplicate", choices: [.init(message: message, finishReason: "tool_calls")], usage: nil
        )
        let repository = RecordingAgentRepository(responses: [response])
        let sut = AgentStreamUseCase(repository: repository)

        // When / Then
        do {
            for try await _ in sut.execute(
                messages: [ChatMessage(role: .user, content: "Hello")],
                model: "test",
                parameters: .default,
                toolRegistry: ToolRegistry(tools: [GetCurrentDatetimeTool()])
            ) {}
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? AgentStreamError, .invalidResponse)
        }
    }
}

private extension AgentStreamUseCaseContextTests {
    func makeToolCall(id: String) -> ToolCall {
        ToolCall(
            id: id,
            type: "function",
            function: ToolCallFunction(name: "get_current_datetime", arguments: "{}")
        )
    }

    func makeToolCallResponse(_ toolCall: ToolCall) -> ChatCompletionResponse {
        let message = ChatCompletionResponse.Message(
            role: "assistant", content: nil, reasoningContent: nil, images: nil, toolCalls: [toolCall]
        )
        return ChatCompletionResponse(
            id: "tool", choices: [.init(message: message, finishReason: "tool_calls")], usage: nil
        )
    }

    func makeStopResponse(content: String) -> ChatCompletionResponse {
        let message = ChatCompletionResponse.Message(
            role: "assistant", content: content, reasoningContent: nil, images: nil, toolCalls: nil
        )
        return ChatCompletionResponse(id: "stop", choices: [.init(message: message, finishReason: "stop")], usage: nil)
    }

    func response(_ response: ChatCompletionResponse, usage: TokenUsage) -> ChatCompletionResponse {
        ChatCompletionResponse(
            id: response.id,
            choices: response.choices,
            usage: .init(
                promptTokens: usage.promptTokens,
                completionTokens: usage.completionTokens,
                totalTokens: usage.totalTokens
            )
        )
    }
}
