//
//  ContextWindowBuilderTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ContextWindowBuilderTests: XCTestCase {
    // MARK: - Tests

    func test_usage_withModelCapacity_returnsPercentage() {
        // Given
        let sut = ContextWindowBuilder()
        let model = LLMModel(id: "test", maxInputTokens: 100)

        // When
        let usage = sut.usage(
            messages: [ChatMessage(role: .user, content: String(repeating: "a", count: 100))],
            systemPrompt: "",
            model: model
        )

        // Then
        XCTAssertEqual(usage?.estimatedInputTokens, 42)
        XCTAssertEqual(usage?.percentage, 47)
    }

    func test_messagesWithinBudget_withLongHistory_keepsMostRecentMessages() {
        // Given
        let sut = ContextWindowBuilder()
        let first = ChatMessage(role: .user, content: String(repeating: "a", count: 100))
        let last = ChatMessage(role: .user, content: String(repeating: "b", count: 100))
        let model = LLMModel(id: "test", maxInputTokens: 80)

        // When
        let messages = sut.messagesWithinBudget([first, last], systemPrompt: "", model: model)

        // Then
        XCTAssertEqual(messages.map(\.id), [last.id])
    }

    func test_messagesWithinBudget_withLargeModel_reservesAtMostTenPercent() {
        // Given
        let sut = ContextWindowBuilder()
        let message = ChatMessage(role: .user, content: String(repeating: "a", count: 300_000))
        let model = LLMModel(id: "test", maxInputTokens: 128_000)

        // When
        let messages = sut.messagesWithinBudget([message], systemPrompt: "", model: model)

        // Then
        XCTAssertEqual(messages.map(\.id), [message.id])
    }

    func test_build_withSummary_includesSummaryInSystemPromptAndExcludesOlderMessages() {
        // Given
        let sut = ContextWindowBuilder()
        let first = ChatMessage(role: .user, content: String(repeating: "a", count: 200))
        let last = ChatMessage(role: .user, content: String(repeating: "b", count: 200))
        let model = LLMModel(id: "test", maxInputTokens: 150)

        // When
        let context = sut.build(
            messages: [first, last],
            systemPrompt: "Follow instructions.",
            summary: "The user prefers concise answers.",
            model: model
        )

        // Then
        XCTAssertEqual(context.messages.map(\.id), [last.id])
        XCTAssertEqual(context.excludedMessages.map(\.id), [first.id])
        XCTAssertTrue(context.effectiveSystemPrompt.contains("The user prefers concise answers."))
    }

    func test_usage_withExcludedHistory_equalsConstructedPayloadEstimate() {
        // Given
        let sut = ContextWindowBuilder()
        let messages = [
            ChatMessage(role: .user, content: String(repeating: "a", count: 100)),
            ChatMessage(role: .assistant, content: String(repeating: "b", count: 100))
        ]
        let model = LLMModel(id: "test", maxInputTokens: 40)

        // When
        let context = sut.build(messages: messages, systemPrompt: "System", summary: nil, model: model)
        let usage = sut.usage(messages: messages, systemPrompt: "System", model: model)

        // Then
        XCTAssertEqual(usage?.estimatedInputTokens, context.estimatedInputTokens)
    }

    func test_usage_withPromptUsage_calibratesEstimate() {
        // Given
        let sut = ContextWindowBuilder()
        let model = LLMModel(id: "test", maxInputTokens: 100)

        // When
        let usage = sut.usage(
            messages: [ChatMessage(role: .user, content: "Hello")],
            systemPrompt: "",
            model: model,
            calibratedPromptTokens: 72
        )

        // Then
        XCTAssertEqual(usage?.estimatedInputTokens, 72)
    }

    func test_usage_withoutModelCapacity_evenWithPromptUsage_returnsNil() {
        // Given
        let sut = ContextWindowBuilder()

        // When
        let usage = sut.usage(
            messages: [ChatMessage(role: .user, content: "Hello")],
            systemPrompt: "",
            model: LLMModel(id: "test"),
            calibratedPromptTokens: 100
        )

        // Then
        XCTAssertNil(usage)
    }

    func test_messagesWithinBudget_middleTurnDoesNotFit_doesNotIncludeOlderTurn() {
        // Given
        let sut = ContextWindowBuilder()
        let old = ChatMessage(role: .user, content: "Old")
        let middle = ChatMessage(role: .user, content: String(repeating: "m", count: 300))
        let recent = ChatMessage(role: .user, content: "Recent")

        // When
        let messages = sut.messagesWithinBudget(
            [old, middle, recent],
            systemPrompt: "",
            model: LLMModel(id: "test", maxInputTokens: 100)
        )

        // Then
        XCTAssertEqual(messages.map(\.id), [recent.id])
    }

    func test_build_latestTurnExceedsLimit_reportsOverflowWithoutOlderMessages() {
        // Given
        let sut = ContextWindowBuilder()
        let old = ChatMessage(role: .user, content: "Old")
        let recent = ChatMessage(role: .user, content: String(repeating: "r", count: 500))

        // When
        let context = sut.build(
            messages: [old, recent],
            systemPrompt: "",
            summary: nil,
            model: LLMModel(id: "test", maxInputTokens: 100)
        )

        // Then
        XCTAssertTrue(context.messages.isEmpty)
        XCTAssertTrue(context.isLatestTurnOverBudget)
        XCTAssertEqual(context.excludedMessages.map(\.id), [old.id, recent.id])
    }

    func test_build_toolTurnDoesNotFit_excludesWholeTurn() {
        // Given
        let sut = ContextWindowBuilder()
        let user = ChatMessage(role: .user, content: "Use a tool")
        let call = ToolCall(
            id: "call_1",
            type: "function",
            function: ToolCallFunction(name: "search", arguments: String(repeating: "a", count: 300))
        )
        let assistant = ChatMessage(role: .assistant, content: "", toolCalls: [call])
        let tool = ChatMessage(role: .tool, content: "Result", toolCallId: call.id, toolName: "search")

        // When
        let context = sut.build(
            messages: [user, assistant, tool],
            systemPrompt: "",
            summary: nil,
            model: LLMModel(id: "test", maxInputTokens: 100)
        )

        // Then
        XCTAssertTrue(context.messages.isEmpty)
        XCTAssertEqual(context.excludedMessages.count, 3)
    }

    func test_usage_compactedAndExcludedMessages_reportsSeparateCounts() {
        // Given
        let sut = ContextWindowBuilder()
        let messages = [
            ChatMessage(role: .user, content: String(repeating: "a", count: 300)),
            ChatMessage(role: .user, content: String(repeating: "b", count: 20))
        ]

        // When
        let usage = sut.usage(
            messages: messages,
            systemPrompt: "",
            model: LLMModel(id: "test", maxInputTokens: 100),
            compactedMessageCount: 4
        )

        // Then
        XCTAssertEqual(usage?.compactedMessageCount, 4)
        XCTAssertEqual(usage?.excludedMessageCount, 1)
    }
}
