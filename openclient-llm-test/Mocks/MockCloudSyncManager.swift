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
    var cloudIds: Set<UUID>?
    var syncedConversations: [Conversation] = []
    var deletedIds: [UUID] = []
    var deleteAllCalled: Bool = false
    var syncError: Error?
    var loadError: Error?
    var cloudProfile: UserProfile?
    var savedProfile: UserProfile?
    var deleteProfileCalled: Bool = false
    var cloudTemplates: [PromptTemplate] = []
    var cloudTemplateIds: Set<UUID>?
    var syncedTemplates: [PromptTemplate] = []
    var deletedTemplateIds: [UUID] = []
    var cloudMemoryItems: [MemoryItem]?
    var savedMemoryItems: [MemoryItem]?
    var deleteMemoryCalled: Bool = false

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

    func allCloudConversationIds() -> Set<UUID>? {
        cloudIds
    }

    func deleteConversationFromCloud(_ conversationId: UUID) throws {
        deletedIds.append(conversationId)
    }

    func deleteAllFromCloud() throws {
        deleteAllCalled = true
    }

    func saveProfileToCloud(_ profile: UserProfile) throws {
        savedProfile = profile
    }

    func loadProfileFromCloud() throws -> UserProfile? {
        cloudProfile
    }

    func deleteProfileFromCloud() throws {
        deleteProfileCalled = true
        cloudProfile = nil
    }

    func syncTemplatesToCloud(_ templates: [PromptTemplate]) throws {
        if let syncError { throw syncError }
        syncedTemplates.append(contentsOf: templates)
    }

    func loadTemplatesFromCloud() throws -> [PromptTemplate] {
        if let loadError { throw loadError }
        return cloudTemplates
    }

    func allCloudTemplateIds() -> Set<UUID>? {
        cloudTemplateIds
    }

    func deleteTemplateFromCloud(_ templateId: UUID) throws {
        deletedTemplateIds.append(templateId)
    }

    func saveMemoryToCloud(_ items: [MemoryItem]) throws {
        savedMemoryItems = items
    }

    func loadMemoryFromCloud() throws -> [MemoryItem]? {
        cloudMemoryItems
    }

    func deleteMemoryFromCloud() throws {
        deleteMemoryCalled = true
        cloudMemoryItems = nil
    }
}
