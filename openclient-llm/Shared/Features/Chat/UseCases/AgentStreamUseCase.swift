//
//  AgentStreamUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - AgentEvent

enum AgentEvent: Sendable {
    case token(String)
    case reasoning(String)
    case toolCallStarted(ToolCall)
    case toolCallCompleted(toolCallId: String, result: String, searchResults: [LiteLLMSearchResult]?)
    case usage(TokenUsage)
    case image(Data)
    case completed
}

// MARK: - ToolCallResult

struct ToolCallResult: Sendable {
    let toolCallId: String
    let toolName: String
    let executionResult: ToolExecutionResult
}

// MARK: - AgentStreamUseCaseProtocol

protocol AgentStreamUseCaseProtocol: Sendable {
    func execute(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        toolRegistry: ToolRegistry
    ) -> AsyncThrowingStream<AgentEvent, Error>
}

// MARK: - AgentStreamUseCase

struct AgentStreamUseCase: AgentStreamUseCaseProtocol {
    // MARK: - Properties

    private static let maxIterations = 10

    private let repository: ChatRepositoryProtocol

    // MARK: - Init

    init(repository: ChatRepositoryProtocol = ChatRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        toolRegistry: ToolRegistry
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await runAgentLoop(
                        messages: messages,
                        model: model,
                        parameters: parameters,
                        toolRegistry: toolRegistry,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - AgentLoopContext

private nonisolated struct AgentLoopContext: @unchecked Sendable {
    let model: String
    let parameters: ModelParameters
    let toolRegistry: ToolRegistry
    let continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
}

// MARK: - Private

private extension AgentStreamUseCase {
    func runAgentLoop(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        toolRegistry: ToolRegistry,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws {
        var conversationMessages = messages
        var iteration = 0
        var toolsJustExecuted = false
        let context = AgentLoopContext(
            model: model,
            parameters: parameters,
            toolRegistry: toolRegistry,
            continuation: continuation
        )

        while iteration < Self.maxIterations {
            guard !Task.isCancelled else { return }
            iteration += 1
            LogManager.debug("agentLoop iteration=\(iteration) messages=\(conversationMessages.count)")

            // After tool execution, omit tools so the model generates a natural response
            let tools: [ToolDefinition]? = toolsJustExecuted ? nil : toolRegistry.definitions
            let response = try await repository.agentCompletion(
                messages: conversationMessages,
                model: model,
                parameters: parameters,
                tools: tools
            )

            guard let choice = response.choices.first else {
                LogManager.warning("agentLoop: empty choices on iteration \(iteration)")
                break
            }

            let shouldContinue = try await handleChoice(
                choice,
                conversationMessages: &conversationMessages,
                context: context
            )
            toolsJustExecuted = shouldContinue
            if !shouldContinue { break }
        }

        if iteration >= Self.maxIterations {
            LogManager.warning("agentLoop reached max iterations (\(Self.maxIterations))")
        }
    }

    func handleChoice(
        _ choice: ChatCompletionResponse.Choice,
        conversationMessages: inout [ChatMessage],
        context: AgentLoopContext
    ) async throws -> Bool {
        let finishReason = choice.finishReason ?? "stop"
        guard finishReason == "tool_calls",
              let toolCalls = choice.message.toolCalls,
              !toolCalls.isEmpty else {
            // Emit the model's answer directly — no second network call needed.
            // The non-streaming agentCompletion already contains the full response.
            if let content = choice.message.content, !content.isEmpty {
                context.continuation.yield(.token(content))
            } else {
                LogManager.warning("agentLoop: stop with empty content")
            }
            return false
        }

        conversationMessages.append(ChatMessage(
            role: .assistant,
            content: choice.message.content ?? "",
            toolCalls: toolCalls
        ))
        let toolResults = try await executeToolCalls(
            toolCalls,
            registry: context.toolRegistry,
            continuation: context.continuation
        )
        for toolResult in toolResults {
            conversationMessages.append(ChatMessage(
                role: .tool,
                content: toolResult.executionResult.text,
                toolCallId: toolResult.toolCallId,
                toolName: toolResult.toolName
            ))
        }
        return true
    }

    func executeToolCalls(
        _ toolCalls: [ToolCall],
        registry: ToolRegistry,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws -> [ToolCallResult] {
        var results: [ToolCallResult] = []

        try await withThrowingTaskGroup(of: ToolCallResult.self) { group in
            for toolCall in toolCalls {
                continuation.yield(.toolCallStarted(toolCall))
                group.addTask {
                    let executionResult: ToolExecutionResult
                    do {
                        executionResult = try await registry.execute(
                            toolName: toolCall.function.name,
                            arguments: toolCall.function.arguments
                        )
                    } catch {
                        executionResult = ToolExecutionResult(
                            text: "Error executing \(toolCall.function.name): \(error.localizedDescription)"
                        )
                    }
                    return ToolCallResult(
                        toolCallId: toolCall.id,
                        toolName: toolCall.function.name,
                        executionResult: executionResult
                    )
                }
            }

            for try await toolCallResult in group {
                results.append(toolCallResult)
                continuation.yield(.toolCallCompleted(
                    toolCallId: toolCallResult.toolCallId,
                    result: toolCallResult.executionResult.text,
                    searchResults: toolCallResult.executionResult.searchResults
                ))
            }
        }

        return results
    }
}
