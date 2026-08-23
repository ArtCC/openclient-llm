//
//  ChatMessageListStateTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 21/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ChatMessageListStateTests: XCTestCase {
    func test_init_agentTranscript_excludesHiddenPayloadsAndKeepsStreamingPlaceholder() {
        // Given
        let user = ChatMessage(role: .user, content: "Question")
        let hiddenAssistant = ChatMessage(
            role: .assistant,
            content: "Internal tool call",
            toolCalls: [ToolCall(
                id: "call-1",
                type: "function",
                function: ToolCallFunction(name: "web_search", arguments: "{}")
            )]
        )
        let tool = ChatMessage(role: .tool, content: String(repeating: "x", count: 100_000))
        let answer = ChatMessage(role: .assistant, content: "Visible answer")
        let placeholder = ChatMessage(role: .assistant, content: "")
        let loadedState = ChatViewModel.LoadedState(
            messages: [user, hiddenAssistant, tool, answer, placeholder],
            isStreaming: true
        )

        // When
        let state = ChatMessageListState(loadedState: loadedState)

        // Then
        XCTAssertEqual(state.messages.map(\.id), [user.id, answer.id, placeholder.id])
        XCTAssertFalse(state.messages.contains { $0.role == .tool })
    }
}
