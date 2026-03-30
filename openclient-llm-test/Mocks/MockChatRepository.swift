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

    var sendMessageResult: Result<String, Error> = .success("Mock response")
    var streamTokens: [String] = []
    var streamError: Error?

    // MARK: - Public

    func sendMessage(messages: [ChatMessage], model: String) async throws -> String {
        try sendMessageResult.get()
    }

    func streamMessage(messages: [ChatMessage], model: String) -> AsyncThrowingStream<String, Error> {
        let tokens = streamTokens
        let error = streamError
        return AsyncThrowingStream { continuation in
            Task {
                for token in tokens {
                    continuation.yield(token)
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
