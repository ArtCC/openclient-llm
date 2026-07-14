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
    case transcriptAppended([ChatMessage])
    case usage(TokenUsage)
    case promptUsage(Int)
    case image(Data)
    case completed
}

// MARK: - AgentStreamError

enum AgentStreamError: LocalizedError, Sendable, Equatable {
    case timedOut
    case iterationLimitReached
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .timedOut:
            String(localized: "The agent timed out before completing the response.")
        case .iterationLimitReached:
            String(localized: "The agent reached its maximum number of steps.")
        case .invalidResponse:
            String(localized: "The model returned an invalid agent response.")
        }
    }
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
        contextWindowTokens: Int?,
        toolRegistry: ToolRegistry
    ) -> AsyncThrowingStream<AgentEvent, Error>
}

// MARK: - AgentStreamUseCase

struct AgentStreamUseCase: AgentStreamUseCaseProtocol {
    // MARK: - Properties

    private static let maxIterations = 10
    private static let maxToolCalls = 20
    private static let maxToolCallsPerIteration = 8
    private static let maximumToolResultCharacters = 12_000
    private let repository: ChatRepositoryProtocol
    private let timeout: Duration

    // MARK: - Init

    init(repository: ChatRepositoryProtocol = ChatRepository(), timeout: Duration = .seconds(125)) {
        self.repository = repository
        self.timeout = timeout
    }

    // MARK: - Execute

    func execute(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        contextWindowTokens: Int? = nil,
        toolRegistry: ToolRegistry
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let context = AgentLoopContext(
                model: model,
                parameters: parameters,
                contextWindowTokens: contextWindowTokens,
                toolRegistry: toolRegistry,
                continuation: continuation
            )
            let task = Task {
                do {
                    try await runAgentLoop(messages: messages, context: context)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                continuation.finish(throwing: AgentStreamError.timedOut)
                task.cancel()
            }
            continuation.onTermination = { _ in
                task.cancel()
                timeoutTask.cancel()
            }
        }
    }
}

// MARK: - AgentLoopContext

private nonisolated struct AgentLoopContext: Sendable {
    let model: String
    let parameters: ModelParameters
    let contextWindowTokens: Int?
    let toolRegistry: ToolRegistry
    let continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
}

private nonisolated struct AgentRoundContext: Sendable {
    let requestMessages: [ChatMessage]
    let loop: AgentLoopContext
}

// MARK: - Private

private extension AgentStreamUseCase {
    func runAgentLoop(messages: [ChatMessage], context: AgentLoopContext) async throws {
        var conversationMessages = messages
        var toolCallCount = 0
        var aggregateUsage = TokenUsage()
        var forceFinalResponse = false

        for iteration in 1...Self.maxIterations {
            try Task.checkCancellation()
            if iteration == Self.maxIterations { forceFinalResponse = true }
            LogManager.debug("agentLoop iteration=\(iteration) messages=\(conversationMessages.count)")
            let tools = forceFinalResponse ? [] : context.toolRegistry.definitions
            let requestMessages = try rebudgetedMessages(
                conversationMessages,
                contextWindowTokens: context.contextWindowTokens,
                tools: tools
            )
            let response = try await request(context: context, messages: requestMessages, tools: tools)
            aggregateUsage = emitUsage(response.usage, aggregate: aggregateUsage, continuation: context.continuation)
            guard let choice = response.choices.first else { throw AgentStreamError.invalidResponse }

            if let toolCalls = choice.message.toolCalls, !toolCalls.isEmpty {
                guard !forceFinalResponse else { throw AgentStreamError.iterationLimitReached }
                forceFinalResponse = try await completeToolRound(
                    choice: choice,
                    toolCalls: toolCalls,
                    conversationMessages: &conversationMessages,
                    toolCallCount: &toolCallCount,
                    context: AgentRoundContext(requestMessages: requestMessages, loop: context)
                )
            } else if handleFinalChoice(choice, continuation: context.continuation) {
                guard !forceFinalResponse else { throw AgentStreamError.invalidResponse }
                forceFinalResponse = true
            } else {
                context.continuation.yield(.completed)
                return
            }
        }
        throw AgentStreamError.iterationLimitReached
    }

    func request(
        context: AgentLoopContext,
        messages: [ChatMessage],
        tools: [ToolDefinition]
    ) async throws -> ChatCompletionResponse {
        try await repository.agentCompletion(
            messages: messages,
            model: context.model,
            parameters: context.parameters,
            tools: tools.isEmpty ? nil : tools
        )
    }

    func completeToolRound(
        choice: ChatCompletionResponse.Choice,
        toolCalls: [ToolCall],
        conversationMessages: inout [ChatMessage],
        toolCallCount: inout Int,
        context: AgentRoundContext
    ) async throws -> Bool {
        guard Set(toolCalls.map(\.id)).count == toolCalls.count else {
            throw AgentStreamError.invalidResponse
        }
        let remaining = max(0, Self.maxToolCalls - toolCallCount)
        let executableCount = min(toolCalls.count, min(Self.maxToolCallsPerIteration, remaining))
        let executable = Array(toolCalls.prefix(executableCount))
        let rejected = Array(toolCalls.dropFirst(executableCount))
        toolCallCount += executable.count
        let assistant = ChatMessage(
            role: .assistant,
            content: choice.message.content ?? "",
            toolCalls: toolCalls
        )
        let willForceFinal = toolCallCount >= Self.maxToolCalls || !rejected.isEmpty
        let nextTools = willForceFinal ? [] : context.loop.toolRegistry.definitions
        let toolPlaceholders = toolCalls.map {
            ChatMessage(role: .tool, content: "", toolCallId: $0.id, toolName: $0.function.name)
        }
        let resultLimit = try toolResultCharacterLimit(
            requestMessages: context.requestMessages + [assistant] + toolPlaceholders,
            contextWindowTokens: context.loop.contextWindowTokens,
            tools: nextTools,
            resultCount: toolCalls.count
        )
        let executedResults = try await executeToolCalls(
            executable,
            registry: context.loop.toolRegistry,
            continuation: context.loop.continuation,
            maximumCharacters: resultLimit
        )
        let results = orderedResults(
            toolCalls: toolCalls,
            executed: executedResults,
            rejected: rejected,
            maximumBytes: resultLimit
        )
        let transcript = [assistant] + results.map(toolMessage)
        conversationMessages.append(contentsOf: transcript)
        context.loop.continuation.yield(.transcriptAppended(transcript))
        return willForceFinal
    }

    func executeToolCalls(
        _ toolCalls: [ToolCall],
        registry: ToolRegistry,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation,
        maximumCharacters: Int
    ) async throws -> [ToolCallResult] {
        try await withThrowingTaskGroup(of: ToolCallResult.self) { group in
            for toolCall in toolCalls {
                continuation.yield(.toolCallStarted(toolCall))
                group.addTask { try await executeToolCall(toolCall, registry: registry) }
            }
            var results: [ToolCallResult] = []
            for try await result in group {
                try Task.checkCancellation()
                let bounded = boundedToolResult(result, maximumCharacters: maximumCharacters)
                results.append(bounded)
                continuation.yield(.toolCallCompleted(
                    toolCallId: bounded.toolCallId,
                    result: bounded.executionResult.text,
                    searchResults: bounded.executionResult.searchResults
                ))
            }
            return results
        }
    }

    func executeToolCall(_ toolCall: ToolCall, registry: ToolRegistry) async throws -> ToolCallResult {
        do {
            let result = try await registry.execute(
                toolName: toolCall.function.name,
                arguments: toolCall.function.arguments
            )
            return ToolCallResult(
                toolCallId: toolCall.id,
                toolName: toolCall.function.name,
                executionResult: result
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ToolCallResult(
                toolCallId: toolCall.id,
                toolName: toolCall.function.name,
                executionResult: ToolExecutionResult(
                    text: "Error executing \(toolCall.function.name): \(error.localizedDescription)"
                )
            )
        }
    }

    func orderedResults(
        toolCalls: [ToolCall],
        executed: [ToolCallResult],
        rejected: [ToolCall],
        maximumBytes: Int
    ) -> [ToolCallResult] {
        let executedById = executed.reduce(into: [String: ToolCallResult]()) { results, result in
            results[result.toolCallId] = result
        }
        let rejectedIds = Set(rejected.map(\.id))
        return toolCalls.compactMap { toolCall in
            if let result = executedById[toolCall.id] { return result }
            guard rejectedIds.contains(toolCall.id) else { return nil }
            let result = ToolCallResult(
                toolCallId: toolCall.id,
                toolName: toolCall.function.name,
                executionResult: ToolExecutionResult(text: "Tool execution skipped: agent tool-call budget exceeded.")
            )
            return boundedToolResult(result, maximumCharacters: maximumBytes)
        }
    }

    func toolMessage(_ result: ToolCallResult) -> ChatMessage {
        ChatMessage(
            role: .tool,
            content: result.executionResult.text,
            toolCallId: result.toolCallId,
            toolName: result.toolName
        )
    }

    func handleFinalChoice(
        _ choice: ChatCompletionResponse.Choice,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) -> Bool {
        let content = choice.message.content ?? ""
        let reasoning = choice.message.reasoningContent
        if content.trimmingCharacters(in: .whitespacesAndNewlines) == "{}" { return true }
        if let reasoning, !reasoning.isEmpty {
            yieldChunked(reasoning, as: { .reasoning($0) }, continuation: continuation)
        }
        if !content.isEmpty {
            yieldChunked(content, as: { .token($0) }, continuation: continuation)
        }
        return content.isEmpty && (reasoning?.isEmpty ?? true)
    }

    func emitUsage(
        _ usage: ChatCompletionResponse.Usage?,
        aggregate: TokenUsage,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) -> TokenUsage {
        guard let usage else { return aggregate }
        let updated = TokenUsage(
            promptTokens: aggregate.promptTokens + (usage.promptTokens ?? 0),
            completionTokens: aggregate.completionTokens + (usage.completionTokens ?? 0),
            totalTokens: aggregate.totalTokens + (usage.totalTokens ?? 0)
        )
        continuation.yield(.usage(updated))
        continuation.yield(.promptUsage(usage.promptTokens ?? 0))
        return updated
    }

    nonisolated func yieldChunked(
        _ text: String,
        as event: @Sendable (String) -> AgentEvent,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) {
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: min(2, text.distance(from: index, to: text.endIndex)))
            continuation.yield(event(String(text[index..<end])))
            index = end
        }
    }

    func boundedToolResult(_ result: ToolCallResult, maximumCharacters: Int) -> ToolCallResult {
        let marker = "\n[Tool result truncated]"
        guard result.executionResult.text.utf8.count > maximumCharacters else { return result }
        guard maximumCharacters > 0 else {
            return ToolCallResult(
                toolCallId: result.toolCallId,
                toolName: result.toolName,
                executionResult: ToolExecutionResult(text: "", searchResults: result.executionResult.searchResults)
            )
        }
        let contentLimit = max(0, maximumCharacters - marker.utf8.count)
        let suffix = maximumCharacters >= marker.utf8.count ? marker : ""
        return ToolCallResult(
            toolCallId: result.toolCallId,
            toolName: result.toolName,
            executionResult: ToolExecutionResult(
                text: utf8Prefix(result.executionResult.text, maximumBytes: contentLimit) + suffix,
                searchResults: result.executionResult.searchResults
            )
        )
    }

    func utf8Prefix(_ text: String, maximumBytes: Int) -> String {
        var result = ""
        var byteCount = 0
        for character in text {
            let bytes = String(character).utf8.count
            guard byteCount + bytes <= maximumBytes else { break }
            result.append(character)
            byteCount += bytes
        }
        return result
    }

    func rebudgetedMessages(
        _ messages: [ChatMessage],
        contextWindowTokens: Int?,
        tools: [ToolDefinition]
    ) throws -> [ChatMessage] {
        guard let contextWindowTokens, contextWindowTokens > 0 else { return messages }
        let systemPrompt = messages.first(where: { $0.role == .system })?.content ?? ""
        let conversation = messages.filter { $0.role != .system }
        let context = ContextWindowBuilder().build(
            messages: conversation,
            systemPrompt: systemPrompt,
            summary: nil,
            model: LLMModel(id: "agent", maxInputTokens: contextWindowTokens),
            tools: tools
        )
        guard !context.isLatestTurnOverBudget else { throw ChatContextError.latestTurnExceedsContextWindow }
        if systemPrompt.isEmpty { return context.messages }
        return [ChatMessage(role: .system, content: systemPrompt)] + context.messages
    }

    func toolResultCharacterLimit(
        requestMessages: [ChatMessage],
        contextWindowTokens: Int?,
        tools: [ToolDefinition],
        resultCount: Int
    ) throws -> Int {
        guard let contextWindowTokens, contextWindowTokens > 0 else { return Self.maximumToolResultCharacters }
        let systemPrompt = requestMessages.first(where: { $0.role == .system })?.content ?? ""
        let messages = requestMessages.filter { $0.role != .system }
        let builder = ContextWindowBuilder()
        let model = LLMModel(id: "agent", maxInputTokens: contextWindowTokens)
        let estimated = builder.estimatedInputTokens(messages: messages, systemPrompt: systemPrompt, tools: tools)
        guard estimated <= builder.usableInputTokens(for: contextWindowTokens) else {
            throw ChatContextError.latestTurnExceedsContextWindow
        }
        let remaining = builder.remainingInputTokens(
            messages: messages,
            systemPrompt: systemPrompt,
            model: model,
            tools: tools
        ) ?? 0
        let characterBudget = max(0, remaining * 3 / max(1, resultCount))
        return min(Self.maximumToolResultCharacters, characterBudget)
    }
}
