//
//  ConversationRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
import WidgetKit

protocol ConversationRepositoryProtocol: Sendable {
    func loadAll() async throws -> [Conversation]
    func loadLocal() async throws -> [Conversation]
    @discardableResult
    func save(_ conversation: Conversation, expectedBase: Conversation?) async throws -> Conversation
    func importBatch(_ conversations: [Conversation]) async throws -> [Conversation]
    func setPinned(_ isPinned: Bool, conversationId: UUID) async throws -> Conversation?
    func rename(_ conversationId: UUID, title: String) async throws -> Conversation?
    func updateTags(_ conversationId: UUID, tags: [ConversationTag]) async throws -> Conversation?
    func delete(_ conversationId: UUID) async throws
    func deleteAll() async throws
    @discardableResult
    func synchronize() async -> ConversationSyncResult
    func cancelSynchronization() async
    func cancelSynchronizationAndDeleteAll() async throws
}

extension ConversationRepositoryProtocol {
    @discardableResult
    func save(_ conversation: Conversation) async throws -> Conversation {
        try await save(conversation, expectedBase: nil)
    }
}

struct ConversationRepository: ConversationRepositoryProtocol {
    // MARK: - Properties

    private static let liveStorage = ConversationStorage()
    private static let liveSyncCoordinator = ConversationSyncCoordinator(storage: liveStorage)

    private let settingsManager: SettingsManagerProtocol
    private let storage: ConversationStorage
    private let syncCoordinator: ConversationSyncCoordinator

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol? = nil,
        attachmentRepository: AttachmentRepositoryProtocol? = nil,
        baseDirectory: URL? = nil,
        storage: ConversationStorage? = nil,
        syncCoordinator: ConversationSyncCoordinator? = nil
    ) {
        self.settingsManager = settingsManager
        if let storage {
            self.storage = storage
            self.syncCoordinator = syncCoordinator ?? ConversationSyncCoordinator(storage: storage)
        } else if baseDirectory != nil || cloudSyncManager != nil || attachmentRepository != nil {
            let manager = cloudSyncManager ?? CloudSyncManager()
            let storage = ConversationStorage(
                cloudSyncManager: manager,
                attachmentRepository: attachmentRepository,
                baseDirectory: baseDirectory
            )
            self.storage = storage
            self.syncCoordinator = syncCoordinator ?? ConversationSyncCoordinator(storage: storage)
        } else {
            self.storage = Self.liveStorage
            self.syncCoordinator = Self.liveSyncCoordinator
        }
    }

    // MARK: - Public

    func loadAll() async throws -> [Conversation] {
        if settingsManager.getIsCloudSyncEnabled() {
            _ = await syncCoordinator.synchronize()
        }
        return try await loadLocal()
    }

    func loadLocal() async throws -> [Conversation] {
        let conversations = try await storage.loadLocal()
        updateWidgetSnapshot(conversations: conversations)
        return conversations
    }

    @discardableResult
    func save(_ conversation: Conversation, expectedBase: Conversation?) async throws -> Conversation {
        let admissionToken = await syncCoordinator.admissionToken()
        let saved = try await syncCoordinator.save(
            conversation,
            expectedBase: expectedBase,
            synchronize: settingsManager.getIsCloudSyncEnabled(),
            admissionToken: admissionToken
        )
        updateWidgetSnapshot(conversations: try await storage.loadLocal())
        return saved
    }

    func importBatch(_ conversations: [Conversation]) async throws -> [Conversation] {
        let saved = try await storage.importBatch(conversations)
        if settingsManager.getIsCloudSyncEnabled() {
            _ = await syncCoordinator.synchronize()
        }
        if let localConversations = try? await storage.loadLocal() {
            updateWidgetSnapshot(conversations: localConversations)
        }
        return saved
    }

    func setPinned(_ isPinned: Bool, conversationId: UUID) async throws -> Conversation? {
        let admissionToken = await syncCoordinator.admissionToken()
        let conversation = try await syncCoordinator.setPinned(
            isPinned,
            conversationId: conversationId,
            synchronize: settingsManager.getIsCloudSyncEnabled(),
            admissionToken: admissionToken
        )
        try await updateAfterMutation(conversation != nil)
        return conversation
    }

    func rename(_ conversationId: UUID, title: String) async throws -> Conversation? {
        let admissionToken = await syncCoordinator.admissionToken()
        let conversation = try await syncCoordinator.rename(
            conversationId,
            title: title,
            synchronize: settingsManager.getIsCloudSyncEnabled(),
            admissionToken: admissionToken
        )
        try await updateAfterMutation(conversation != nil)
        return conversation
    }

    func updateTags(_ conversationId: UUID, tags: [ConversationTag]) async throws -> Conversation? {
        let admissionToken = await syncCoordinator.admissionToken()
        let conversation = try await syncCoordinator.updateTags(
            conversationId,
            tags: tags,
            synchronize: settingsManager.getIsCloudSyncEnabled(),
            admissionToken: admissionToken
        )
        try await updateAfterMutation(conversation != nil)
        return conversation
    }

    func delete(_ conversationId: UUID) async throws {
        let admissionToken = await syncCoordinator.admissionToken()
        try await syncCoordinator.delete(
            conversationId,
            synchronize: settingsManager.getIsCloudSyncEnabled(),
            admissionToken: admissionToken
        )
        updateWidgetSnapshot(conversations: try await storage.loadLocal())
    }

    func deleteAll() async throws {
        let shouldSynchronize = settingsManager.getIsCloudSyncEnabled()
        let admissionToken = await syncCoordinator.admissionToken()
        try await syncCoordinator.deleteAll(
            synchronize: shouldSynchronize,
            admissionToken: admissionToken
        )
        clearWidgetSnapshot()
    }

    @discardableResult
    func synchronize() async -> ConversationSyncResult {
        guard settingsManager.getIsCloudSyncEnabled() else { return .unavailable }
        let result = await syncCoordinator.synchronize()
        if let conversations = try? await storage.loadLocal() {
            updateWidgetSnapshot(conversations: conversations)
        }
        return result
    }

    func cancelSynchronization() async {
        await syncCoordinator.cancel()
    }

    func cancelSynchronizationAndDeleteAll() async throws {
        try await syncCoordinator.cancelAndDeleteAll()
        clearWidgetSnapshot()
    }
}

// MARK: - Private

private extension ConversationRepository {
    func clearWidgetSnapshot() {
        guard AppGroupStore.clearConversations() else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.conversationsWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.pinnedConversationsWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.latestConversationWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.taggedConversationsWidgetKind)
    }

    func updateAfterMutation(_ didMutate: Bool) async throws {
        guard didMutate else { return }
        updateWidgetSnapshot(conversations: try await storage.loadLocal())
    }

    func updateWidgetSnapshot(conversations: [Conversation]) {
        let sorted = conversations.sorted { $0.updatedAt > $1.updatedAt }
        let recentConversations = makeWidgetConversations(from: Array(sorted.prefix(6)))
        let pinnedConversations = makeWidgetConversations(from: sorted.filter(\.isPinned))
        let tags = Array(Set(conversations.flatMap(\.tags).map(\.name))).sorted()
        let recentChanged = AppGroupStore.saveConversations(recentConversations)
        let pinnedChanged = AppGroupStore.savePinnedConversations(pinnedConversations)
        let tagsChanged = AppGroupStore.saveTags(tags)
        if recentChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.conversationsWidgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.latestConversationWidgetKind)
        }
        if pinnedChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.pinnedConversationsWidgetKind)
        }
        if tagsChanged || recentChanged || pinnedChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.taggedConversationsWidgetKind)
        }
    }

    func makeWidgetConversations(from conversations: [Conversation]) -> [WidgetConversation] {
        conversations.map { conversation in
            WidgetConversation(
                id: conversation.id,
                title: conversation.title.isEmpty ? String(localized: "New Chat") : conversation.title,
                modelId: conversation.modelId,
                lastMessagePreview: conversation.messages.last?.content
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                updatedAt: conversation.updatedAt,
                isPinned: conversation.isPinned,
                tags: conversation.tags.map(\.name)
            )
        }
    }
}
