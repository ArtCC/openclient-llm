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
    var executeCallCount = 0

    func execute() -> ConversationSyncResult {
        executeCallCount += 1
        return result
    }
}
