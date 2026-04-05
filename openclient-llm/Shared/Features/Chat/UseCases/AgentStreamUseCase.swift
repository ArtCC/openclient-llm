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
    case toolCallCompleted(toolCallId: String, result: String)
    case usage(TokenUsage)
    case image(Data)
    case completed
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

            let response = try await repository.agentCompletion(
                messages: conversationMessages,
                model: model,
                parameters: parameters,
                tools: toolRegistry.definitions
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
            if let content = choice.message.content, !content.isEmpty {
                try await streamFinalResponse(
                    messages: conversationMessages,
                    model: context.model,
                    parameters: context.parameters,
                    continuation: context.continuation
                )
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
        for (toolCallId, result) in toolResults {
            conversationMessages.append(ChatMessage(role: .tool, content: result, toolCallId: toolCallId))
        }
        return true
    }

    func executeToolCalls(
        _ toolCalls: [ToolCall],
        registry: ToolRegistry,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws -> [(String, String)] {
        var results: [(String, String)] = []

        try await withThrowingTaskGroup(of: (String, String).self) { group in
            for toolCall in toolCalls {
                continuation.yield(.toolCallStarted(toolCall))
                group.addTask {
                    let result: String
                    do {
                        result = try await registry.execute(
                            toolName: toolCall.function.name,
                            arguments: toolCall.function.arguments
                        )
                    } catch {
                        result = "Error executing \(toolCall.function.name): \(error.localizedDescription)"
                    }
                    return (toolCall.id, result)
                }
            }

            for try await (id, result) in group {
                results.append((id, result))
                continuation.yield(.toolCallCompleted(toolCallId: id, result: result))
            }
        }

        return results
    }

    func streamFinalResponse(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws {
        LogManager.debug("agentLoop streaming final response messages=\(messages.count)")
        let stream = repository.streamMessage(messages: messages, model: model, parameters: parameters)

        for try await chunk in stream {
            guard !Task.isCancelled else { return }
            switch chunk {
            case .token(let text):
                continuation.yield(.token(text))
            case .reasoning(let text):
                continuation.yield(.reasoning(text))
            case .usage(let usage):
                continuation.yield(.usage(usage))
            case .image(let data):
                continuation.yield(.image(data))
            }
        }
    }
}
