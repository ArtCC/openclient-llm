//
//  MockCloudSyncManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Repository tests inject one instance into one ConversationStorage actor and inspect it only after
// awaited calls.
// Other tests access their instance only from serialized @MainActor test methods.
final class MockCloudSyncManager: CloudSyncManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var cloudAvailable: Bool = true
    var checkCloudAvailabilityCallCount = 0
    var cloudConversations: [Conversation] = []
    var cloudIds: Set<UUID>?
    var syncedConversations: [Conversation] = []
    var deletedIds: [UUID] = []
    var deleteAllCalled: Bool = false
    var syncError: Error?
    var validationError: Error?
    var loadError: Error?
    var cloudProfile: UserProfile?
    var cloudProfileDeletionMarker: CloudDeletionMarker?
    var savedProfile: UserProfile?
    var deleteProfileCalled: Bool = false
    var cloudTemplates: [PromptTemplate] = []
    var cloudTemplateIds: Set<UUID>?
    var cloudTemplateDeletionMarkers: [UUID: CloudDeletionMarker] = [:]
    var syncedTemplates: [PromptTemplate] = []
    var deletedTemplateIds: [UUID] = []
    var cloudMemoryItems: [MemoryItem]?
    var cloudMemoryDeletionMarkers: [CloudDeletionMarker] = []
    var savedMemoryItems: [MemoryItem]?
    var deleteMemoryCalled: Bool = false
    var pendingConversationDownloads: Bool = false
    var cloudTombstones: [ConversationTombstone] = []
    var cloudDeleteAllMarker: ConversationDeleteAllMarker?
    var cloudAttachmentData: [CloudAttachmentKey: Data] = [:]
    var materializedConversationIds: [UUID] = []
    var loadConversationsCallCount = 0
    var loadConversationsHandler: (() -> Void)?
    var loadConversationsSendableHandler: (@Sendable () -> Void)?

    // MARK: - Public

    func isCloudAvailable() -> Bool {
        cloudAvailable
    }

    func checkCloudAvailability() async -> Bool {
        checkCloudAvailabilityCallCount += 1
        return cloudAvailable
    }

    func loadConversationSyncSnapshot() throws -> ConversationCloudSyncSnapshot {
        loadConversationsCallCount += 1
        loadConversationsHandler?()
        loadConversationsSendableHandler?()
        if pendingConversationDownloads { throw CloudSyncError.requiredDownloadPending }
        if let loadError { throw loadError }
        let encoder = SyncJSONCoding.makeEncoder()
        let conversationData = try Dictionary(uniqueKeysWithValues: cloudConversations.map {
            ($0.id, try encoder.encode($0))
        })
        let decoder = SyncJSONCoding.makeDecoder()
        let canonicalConversations = try Dictionary(uniqueKeysWithValues: conversationData.map { id, data in
            (id, try decoder.decode(Conversation.self, from: data))
        })
        let tombstoneData = try Dictionary(uniqueKeysWithValues: cloudTombstones.map {
            ($0.conversationId, try encoder.encode($0))
        })
        return ConversationCloudSyncSnapshot(
            session: CloudSyncSession(
                containerURL: URL(fileURLWithPath: "/mock-cloud"),
                identity: Data("mock-cloud".utf8)
            ),
            manifestData: nil,
            conversations: canonicalConversations,
            conversationData: conversationData,
            tombstones: cloudTombstones,
            tombstoneData: tombstoneData,
            legacyTombstoneData: nil,
            deleteAllMarker: cloudDeleteAllMarker,
            deleteAllMarkerData: try cloudDeleteAllMarker.map { try encoder.encode($0) },
            attachmentData: cloudAttachmentData,
            attachmentPlaceholders: []
        )
    }

    func applyConversationSyncOutput(
        _ output: ConversationCloudSyncOutput,
        basedOn snapshot: ConversationCloudSyncSnapshot
    ) throws {
        if let syncError { throw syncError }
        let outputIds = Set(output.conversations.map(\.id))
        deletedIds.append(contentsOf: Set(cloudConversations.map(\.id)).subtracting(outputIds))
        syncedConversations.append(contentsOf: output.conversations)
        cloudConversations = output.conversations
        cloudTombstones = output.tombstones
        cloudDeleteAllMarker = output.deleteAllMarker
        cloudAttachmentData = output.attachments
    }

    func validateConversationSyncOutput(
        _ output: ConversationCloudSyncOutput,
        basedOn snapshot: ConversationCloudSyncSnapshot
    ) throws {
        if let validationError { throw validationError }
    }

    func syncConversationsToCloud(_ conversations: [Conversation]) throws {
        if let syncError { throw syncError }
        syncedConversations.append(contentsOf: conversations)
        for conversation in conversations {
            cloudConversations.removeAll { $0.id == conversation.id }
            cloudConversations.append(conversation)
        }
    }

    func loadConversationsFromCloud() throws -> [Conversation] {
        loadConversationsCallCount += 1
        loadConversationsHandler?()
        if let loadError { throw loadError }
        return cloudConversations
    }

    func allCloudConversationIds() throws -> Set<UUID>? {
        cloudIds
    }

    func deleteConversationFromCloud(_ conversationId: UUID) throws {
        deletedIds.append(conversationId)
        cloudConversations.removeAll { $0.id == conversationId }
    }

    func deleteAllFromCloud() throws {
        deleteAllCalled = true
    }

    func hasPendingConversationDownloads() throws -> Bool {
        pendingConversationDownloads
    }

    func materializeAttachmentsFromCloud(for conversation: Conversation) throws -> Bool {
        materializedConversationIds.append(conversation.id)
        return !pendingConversationDownloads
    }

    func loadConversationTombstonesFromCloud() throws -> [ConversationTombstone] {
        if let loadError { throw loadError }
        return cloudTombstones
    }

    func saveConversationTombstonesToCloud(_ tombstones: [ConversationTombstone]) throws {
        if let syncError { throw syncError }
        cloudTombstones = tombstones
    }

    func loadConversationDeleteAllMarkerFromCloud() throws -> ConversationDeleteAllMarker? {
        cloudDeleteAllMarker
    }

    func saveConversationDeleteAllMarkerToCloud(_ marker: ConversationDeleteAllMarker) throws {
        cloudDeleteAllMarker = marker
    }

    func saveProfileToCloud(_ profile: UserProfile) async throws {
        if let syncError { throw syncError }
        savedProfile = profile
        cloudProfile = profile
        cloudProfileDeletionMarker = nil
    }

    func loadProfileFromCloud() async throws -> UserProfile? {
        if let loadError { throw loadError }
        guard case .profile(let profile) = try await loadProfileStateFromCloud() else { return nil }
        return profile
    }

    func loadProfileStateFromCloud() async throws -> CloudUserProfileState {
        if let loadError { throw loadError }
        if let marker = cloudProfileDeletionMarker {
            guard let cloudProfile, cloudProfile.modifiedAt > marker.deletedAt else { return .deleted(marker) }
            return .profile(cloudProfile)
        }
        return cloudProfile.map(CloudUserProfileState.profile) ?? .missing
    }

    func deleteProfileFromCloud() async throws {
        if let syncError { throw syncError }
        deleteProfileCalled = true
        cloudProfile = nil
        cloudProfileDeletionMarker = CloudDeletionMarker(id: CloudSyncManager.profileMarkerId, deletedAt: Date())
    }

    func syncTemplatesToCloud(_ templates: [PromptTemplate]) async throws {
        if let syncError { throw syncError }
        for template in templates {
            if let marker = cloudTemplateDeletionMarkers[template.id], template.updatedAt <= marker.deletedAt {
                cloudTemplates.removeAll { $0.id == template.id && $0.updatedAt <= marker.deletedAt }
                continue
            }
            syncedTemplates.append(template)
            cloudTemplates.removeAll { $0.id == template.id }
            cloudTemplates.append(template)
            cloudTemplateDeletionMarkers.removeValue(forKey: template.id)
        }
        cloudTemplateIds = Set(cloudTemplates.map(\.id))
    }

    func loadTemplatesFromCloud() async throws -> PromptTemplateCloudSnapshot {
        if let loadError { throw loadError }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let templates = cloudTemplates.filter { template in
            guard let marker = cloudTemplateDeletionMarkers[template.id] else { return true }
            return template.updatedAt > marker.deletedAt
        }
        let data = try Dictionary(uniqueKeysWithValues: templates.map {
            ($0.id, try encoder.encode($0))
        })
        return PromptTemplateCloudSnapshot(
            templates: templates,
            templateData: data,
            deletionMarkers: cloudTemplateDeletionMarkers
        )
    }

    func deleteTemplateFromCloud(_ templateId: UUID, deletedAt: Date) async throws {
        if let syncError { throw syncError }
        deletedTemplateIds.append(templateId)
        let existingDate = cloudTemplateDeletionMarkers[templateId]?.deletedAt ?? .distantPast
        let effectiveDate = max(existingDate, deletedAt)
        cloudTemplateDeletionMarkers[templateId] = CloudDeletionMarker(id: templateId, deletedAt: effectiveDate)
        cloudTemplates.removeAll { $0.id == templateId && $0.updatedAt <= effectiveDate }
        if !cloudTemplates.contains(where: { $0.id == templateId }) {
            cloudTemplateIds?.remove(templateId)
        }
    }

    func saveMemoryToCloud(_ items: [MemoryItem]) async throws {
        if let syncError { throw syncError }
        savedMemoryItems = items
        cloudMemoryItems = items.filter { item in
            guard let marker = cloudMemoryDeletionMarkers.first(where: { $0.id == item.id }) else { return true }
            return item.updatedAt > marker.deletedAt
        }
    }

    func loadMemorySyncSnapshot() async throws -> MemoryCloudSyncSnapshot {
        if let loadError { throw loadError }
        let eligibleItems = cloudMemoryItems?.filter { item in
            guard let marker = cloudMemoryDeletionMarkers.first(where: { $0.id == item.id }) else { return true }
            return item.updatedAt > marker.deletedAt
        }
        return MemoryCloudSyncSnapshot(
            items: eligibleItems,
            deletionMarkers: cloudMemoryDeletionMarkers
        )
    }

    func deleteMemoryItemFromCloud(_ itemId: UUID, deletedAt: Date) async throws {
        if let syncError { throw syncError }
        let existingDate = cloudMemoryDeletionMarkers
            .first(where: { $0.id == itemId })?
            .deletedAt ?? .distantPast
        let effectiveDate = max(existingDate, deletedAt)
        cloudMemoryDeletionMarkers.removeAll { $0.id == itemId }
        cloudMemoryDeletionMarkers.append(CloudDeletionMarker(id: itemId, deletedAt: effectiveDate))
        cloudMemoryItems?.removeAll { $0.id == itemId && $0.updatedAt <= effectiveDate }
    }

}
