//
//  MockChatRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    // MARK: - Properties

    var sendMessageResult: Result<(String, TokenUsage?), Error> = .success(("Mock response", nil))
    var streamChunks: [StreamChunk] = []
    var streamError: Error?

    // MARK: - Public

    func sendMessage(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters
    ) async throws -> (String, TokenUsage?) {
        try sendMessageResult.get()
    }

    func streamMessage(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        let chunks = streamChunks
        let error = streamError
        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        }
    }
}
