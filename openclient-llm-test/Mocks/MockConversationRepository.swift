//
//  MockConversationRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockConversationRepository: ConversationRepositoryProtocol, @unchecked Sendable {
    // MARK: - Properties

    var conversations: [Conversation] = []
    var saveError: Error?
    var deleteError: Error?
    var loadError: Error?
    var savedConversations: [Conversation] = []
    var deletedIds: [UUID] = []

    // MARK: - Public

    func loadAll() throws -> [Conversation] {
        if let loadError { throw loadError }
        return conversations
    }

    func save(_ conversation: Conversation) throws {
        if let saveError { throw saveError }
        savedConversations.append(conversation)
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
    }

    func delete(_ conversationId: UUID) throws {
        if let deleteError { throw deleteError }
        deletedIds.append(conversationId)
        conversations.removeAll { $0.id == conversationId }
    }

    func deleteAll() throws {
        conversations.removeAll()
    }
}
