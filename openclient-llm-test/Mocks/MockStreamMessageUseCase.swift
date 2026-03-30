//
//  MockStreamMessageUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockStreamMessageUseCase: StreamMessageUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var tokens: [String] = []
    var error: Error?

    // MARK: - Execute

    func execute(messages: [ChatMessage], model: String) -> AsyncThrowingStream<String, Error> {
        let tokens = tokens
        let error = error
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
