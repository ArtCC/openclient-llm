//
//  MockAgentStreamUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockAgentStreamUseCase: AgentStreamUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var events: [AgentEvent] = []
    var error: Error?

    // MARK: - Execute

    func execute(
        messages: [ChatMessage],
        model: String,
        parameters: ModelParameters,
        toolRegistry: ToolRegistry
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        let events = events
        let error = error
        return AsyncThrowingStream { continuation in
            Task {
                for event in events {
                    continuation.yield(event)
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
