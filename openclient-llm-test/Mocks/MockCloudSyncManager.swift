//
//  MockCloudSyncManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockCloudSyncManager: CloudSyncManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var cloudAvailable: Bool = true
    var cloudConversations: [Conversation] = []
    var syncedConversations: [Conversation] = []
    var deletedIds: [UUID] = []
    var deleteAllCalled: Bool = false
    var syncError: Error?
    var loadError: Error?

    // MARK: - Public

    func isCloudAvailable() -> Bool {
        cloudAvailable
    }

    func syncConversationsToCloud(_ conversations: [Conversation]) throws {
        if let syncError { throw syncError }
        syncedConversations.append(contentsOf: conversations)
    }

    func loadConversationsFromCloud() throws -> [Conversation] {
        if let loadError { throw loadError }
        return cloudConversations
    }

    func deleteConversationFromCloud(_ conversationId: UUID) throws {
        deletedIds.append(conversationId)
    }

    func deleteAllFromCloud() throws {
        deleteAllCalled = true
    }
}
