//
//  MockCompactConversationUseCase.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockCompactConversationUseCase: CompactConversationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: CompactedConversation?
    var results: [CompactedConversation?] = []
    var error: Error?
    var shouldSuspend = false
    private(set) var callCount = 0
    private var continuation: CheckedContinuation<CompactedConversation?, Error>?

    // MARK: - Execute

    func execute(
        messages: [ChatMessage],
        configuration: CompactionConfiguration
    ) async throws -> CompactedConversation? {
        callCount += 1
        if let error { throw error }
        guard shouldSuspend else {
            return results.isEmpty ? result : results.removeFirst()
        }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func resume() {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
