//
//  AgentStreamConfigurationTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class AgentStreamConfigurationTests: XCTestCase {
    func test_execute_serverConfigurationChangesDuringRequest_discardsResponse() async {
        // Given
        let configuration = AgentConfigurationState()
        let repository = ConfigurationAgentRepository {
            configuration.isCurrent = false
        }
        let sut = AgentStreamUseCase(repository: repository)

        // When
        let caughtError: Error?
        do {
            for try await _ in sut.execute(
                messages: [ChatMessage(role: .user, content: "Hello")],
                model: "test-model",
                parameters: .default,
                toolContext: AgentToolContext(
                    toolRegistry: ToolRegistry(tools: []),
                    isConfigurationCurrent: { configuration.isCurrent }
                )
            ) {}
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? AgentStreamError, .configurationChanged)
        XCTAssertEqual(repository.callCount, 1)
    }

    func test_execute_serverConfigurationChangesDuringToolExecution_discardsToolResult() async {
        // Given
        let configuration = AgentConfigurationState()
        let toolCall = ToolCall(
            id: "call",
            type: "function",
            function: ToolCallFunction(name: "changing_tool", arguments: "{}")
        )
        let repository = ConfigurationAgentRepository(response: .toolCall(toolCall)) {}
        let sut = AgentStreamUseCase(repository: repository)
        let registry = ToolRegistry(tools: [ConfigurationChangingTool(configuration: configuration)])

        // When
        let caughtError: Error?
        do {
            for try await _ in sut.execute(
                messages: [ChatMessage(role: .user, content: "Hello")],
                model: "test-model",
                parameters: .default,
                toolContext: AgentToolContext(
                    toolRegistry: registry,
                    isConfigurationCurrent: { configuration.isCurrent }
                )
            ) {}
            caughtError = nil
        } catch {
            caughtError = error
        }

        // Then
        XCTAssertEqual(caughtError as? AgentStreamError, .configurationChanged)
        XCTAssertEqual(repository.callCount, 1)
    }
}

@MainActor
private final class AgentConfigurationState {
    var isCurrent = true
}

// Safety: Only used within serialized @MainActor test methods.
private final class ConfigurationAgentRepository: ChatRepositoryProtocol, @unchecked Sendable {
    private let response: ChatCompletionResponse
    private let onCompletion: () -> Void
    private(set) var callCount = 0

    init(
        response: ChatCompletionResponse = .finalResponse,
        onCompletion: @escaping () -> Void
    ) {
        self.response = response
        self.onCompletion = onCompletion
    }

    func sendMessage(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters
    ) async throws -> (String, TokenUsage?) {
        ("", nil)
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
        callCount += 1
        onCompletion()
        return response
    }
}

private struct ConfigurationChangingTool: ChatToolProtocol {
    let configuration: AgentConfigurationState

    var definition: ToolDefinition {
        ToolDefinition(
            type: "function",
            function: ToolFunctionDefinition(
                name: "changing_tool",
                description: "Change the test configuration",
                parameters: ToolParameters(type: "object", properties: [:], required: [])
            )
        )
    }

    func execute(arguments: String) async throws -> ToolExecutionResult {
        configuration.isCurrent = false
        return ToolExecutionResult(text: "Discarded")
    }
}

private extension ChatCompletionResponse {
    static var finalResponse: ChatCompletionResponse {
        ChatCompletionResponse(
            id: "response",
            choices: [ChatCompletionResponse.Choice(
                message: ChatCompletionResponse.Message(
                    role: "assistant",
                    content: "Should be discarded",
                    reasoningContent: nil,
                    images: nil,
                    toolCalls: nil
                ),
                finishReason: "stop"
            )],
            usage: nil
        )
    }

    static func toolCall(_ toolCall: ToolCall) -> ChatCompletionResponse {
        ChatCompletionResponse(
            id: "tool-response",
            choices: [ChatCompletionResponse.Choice(
                message: ChatCompletionResponse.Message(
                    role: "assistant",
                    content: nil,
                    reasoningContent: nil,
                    images: nil,
                    toolCalls: [toolCall]
                ),
                finishReason: "tool_calls"
            )],
            usage: nil
        )
    }
}
