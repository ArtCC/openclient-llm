//
//  AgentStreamUseCasePresentationTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 27/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension AgentStreamUseCaseTests {
    func test_execute_responseWithReasoning_emitsReasoningBeforeContentWithoutLosingText() async throws {
        // Given
        mockRepository.agentCompletionResult = .success(
            makePresentationResponse(content: "Final answer", reasoning: "Think first")
        )

        // When
        var reasoning = ""
        var content = ""
        var didReceiveContent = false
        var reasoningArrivedAfterContent = false
        let stream = sut.execute(
            messages: [ChatMessage(role: .user, content: "Hi")],
            model: "gpt-4",
            parameters: .default,
            toolRegistry: toolRegistry
        )
        for try await event in stream {
            switch event {
            case .reasoning(let text):
                reasoning += text
                reasoningArrivedAfterContent = reasoningArrivedAfterContent || didReceiveContent
            case .token(let text):
                content += text
                didReceiveContent = true
            default:
                break
            }
        }

        // Then
        XCTAssertEqual(reasoning, "Think first")
        XCTAssertEqual(content, "Final answer")
        XCTAssertFalse(reasoningArrivedAfterContent)
    }

    func test_execute_extremelyLongFinalResponse_limitsPresentationUpdates() async throws {
        // Given
        let content = String(repeating: "a", count: 100_000)
        mockRepository.agentCompletionResult = .success(makePresentationResponse(content: content))

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
        XCTAssertEqual(tokens.joined(), content)
        XCTAssertLessThanOrEqual(tokens.count, 300)
    }

    func test_execute_whitespaceOnlyResponse_retriesWithoutEmittingBlankContent() async throws {
        // Given
        let repository = RecordingAgentRepository(responses: [
            makePresentationResponse(content: " \n\t "),
            makePresentationResponse(content: "Final answer")
        ])
        let whitespaceSUT = AgentStreamUseCase(repository: repository, chunkDelay: .zero)

        // When
        var tokens: [String] = []
        let stream = whitespaceSUT.execute(
            messages: [ChatMessage(role: .user, content: "Hi")],
            model: "gpt-4",
            parameters: .default,
            toolRegistry: ToolRegistry(tools: [GetCurrentDatetimeTool()])
        )
        for try await event in stream {
            if case .token(let text) = event { tokens.append(text) }
        }

        // Then
        XCTAssertEqual(tokens.joined(), "Final answer")
        XCTAssertEqual(repository.requests.count, 2)
        XCTAssertFalse(repository.toolRequests[0]?.isEmpty ?? true)
        XCTAssertNil(repository.toolRequests[1])
    }
}

private extension AgentStreamUseCaseTests {
    func makePresentationResponse(content: String, reasoning: String? = nil) -> ChatCompletionResponse {
        let message = ChatCompletionResponse.Message(
            role: "assistant", content: content, reasoningContent: reasoning, images: nil, toolCalls: nil
        )
        return ChatCompletionResponse(
            id: "presentation-response",
            choices: [ChatCompletionResponse.Choice(message: message, finishReason: "stop")],
            usage: nil
        )
    }
}
