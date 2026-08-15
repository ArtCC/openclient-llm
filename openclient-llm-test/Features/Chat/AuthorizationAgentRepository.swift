//
//  AuthorizationAgentRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class AuthorizationAgentRepository: ChatRepositoryProtocol, @unchecked Sendable {
    var responses: [ChatCompletionResponse]
    var requests: [[ChatMessage]] = []
    var callIndex = 0

    init(responses: [ChatCompletionResponse]) {
        self.responses = responses
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
        requests.append(messages)
        let response = responses[callIndex]
        callIndex += 1
        return response
    }
}
