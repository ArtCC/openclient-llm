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
    var onExecute: ((Int, CompactionConfiguration) -> Void)?
    private(set) var callCount = 0
    private(set) var receivedConfigurations: [CompactionConfiguration] = []

    // MARK: - Execute

    func execute(
        messages: [ChatMessage],
        configuration: CompactionConfiguration
    ) async throws -> CompactedConversation? {
        callCount += 1
        receivedConfigurations.append(configuration)
        onExecute?(callCount, configuration)
        if let error { throw error }
        return results.isEmpty ? result : results.removeFirst()
    }
}
