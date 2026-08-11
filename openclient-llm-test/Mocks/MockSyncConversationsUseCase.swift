//
//  MockSyncConversationsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSyncConversationsUseCase: SyncConversationsUseCaseProtocol, @unchecked Sendable {
    var result: ConversationSyncResult = .synchronized
    var results: [ConversationSyncResult] = []
    var executeCallCount = 0
    var cancelCallCount = 0
    var cancelHandler: (@Sendable () async -> Void)?

    func execute() async -> ConversationSyncResult {
        executeCallCount += 1
        if !results.isEmpty {
            return results.removeFirst()
        }
        return result
    }

    func cancel() async {
        cancelCallCount += 1
        await cancelHandler?()
    }
}
