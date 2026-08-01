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
    func loadAll() throws -> [Conversation]
    func loadLocal() throws -> [Conversation]
    func save(_ conversation: Conversation) throws
    func delete(_ conversationId: UUID) throws
    func deleteAll() throws
    @discardableResult
    func synchronize() -> ConversationSyncResult
}

struct ConversationRepository: ConversationRepositoryProtocol {
    // MARK: - Properties

    private let fileManager: FileManager
    private let directoryURL: URL
    private let tombstonesURL: URL
    private let deleteAllMarkerURL: URL
    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        attachmentRepository: AttachmentRepositoryProtocol = AttachmentRepository(),
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        let documentsURL = baseDirectory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directoryURL = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        self.tombstonesURL = documentsURL.appendingPathComponent("ConversationTombstones.json")
        self.deleteAllMarkerURL = documentsURL.appendingPathComponent("ConversationDeleteAll.json")
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.attachmentRepository = attachmentRepository
    }

    // MARK: - Public

    func loadAll() throws -> [Conversation] {
        LogManager.debug("loadAll conversations")
        try ensureDirectoryExists()

        if settingsManager.getIsCloudSyncEnabled() {
            _ = synchronize()
        }
        return try loadLocal()
    }

    func loadLocal() throws -> [Conversation] {
        LogManager.debug("loadLocal conversations")
        try ensureDirectoryExists()

        let localConversations = try loadLocalConversations()

        let sorted = localConversations.sorted { $0.updatedAt > $1.updatedAt }
        updateWidgetSnapshot(conversations: sorted)
        LogManager.success("loadLocal returned \(sorted.count) conversations")
        return sorted
    }

    func save(_ conversation: Conversation) throws {
        LogManager.debug("save conversation id=\(conversation.id) title='\(conversation.title)'")
        try ensureDirectoryExists()
        try saveLocal(conversation)

        if settingsManager.getIsCloudSyncEnabled() {
            _ = synchronize()
        }

        updateWidgetSnapshot()
    }

    func delete(_ conversationId: UUID) throws {
        LogManager.debug("delete conversation id=\(conversationId)")
        // Load conversation before deleting so we can clean up its attachment files
        let fileURL = directoryURL.appendingPathComponent("\(conversationId.uuidString).json")
        if let data = try? Data(contentsOf: fileURL),
           let conversation = try? JSONDecoder.iso8601.decode(Conversation.self, from: data) {
            deleteAttachments(for: conversation)
        }
        try saveTombstones(mergedTombstones([ConversationTombstone(conversationId: conversationId, deletedAt: Date())]))
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        LogManager.success("delete conversation id=\(conversationId) done")

        if settingsManager.getIsCloudSyncEnabled() {
            _ = synchronize()
        }

        updateWidgetSnapshot()
    }

    func deleteAll() throws {
        LogManager.warning("deleteAll conversations")
        if settingsManager.getIsCloudSyncEnabled() {
            try saveDeleteAllMarker(ConversationDeleteAllMarker(deletedAt: Date()))
        }
        if fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.removeItem(at: directoryURL)
        }
        try ensureDirectoryExists()
        try? attachmentRepository.deleteAll()
        LogManager.success("deleteAll conversations done")

        if settingsManager.getIsCloudSyncEnabled() {
            _ = synchronize()
        }

        if AppGroupStore.clearConversations() {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.conversationsWidgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.taggedConversationsWidgetKind)
        }
    }

    @discardableResult
    func synchronize() -> ConversationSyncResult {
        guard settingsManager.getIsCloudSyncEnabled(), cloudSyncManager.isCloudAvailable() else {
            return .unavailable
        }
        do {
            try ensureDirectoryExists()
            if try cloudSyncManager.hasPendingConversationDownloads() {
                return .pendingDownload
            }
            return try synchronizeAvailableCloud()
        } catch {
            LogManager.error("Conversation synchronization failed: \(error)")
            return .failed
        }
    }
}

// MARK: - Private

private extension ConversationRepository {
    func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func loadLocalConversations() throws -> [Conversation] {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var conversations: [Conversation] = []
        for url in fileURLs where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let conversation = try decoder.decode(Conversation.self, from: data)
                conversations.append(conversation)
            } catch {
                LogManager.error("Failed to decode conversation at \(url.lastPathComponent): \(error)")
                continue
            }
        }
        return conversations
    }

    func saveLocal(_ conversation: Conversation) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(conversation)
        let fileURL = directoryURL.appendingPathComponent("\(conversation.id.uuidString).json")
        try writeIfChanged(data, to: fileURL)
    }

    func mergeConversations(
        local: [Conversation],
        cloud: [Conversation],
        tombstones: [ConversationTombstone],
        deleteAllMarker: ConversationDeleteAllMarker?
    ) -> [Conversation] {
        let deletedAt = Dictionary(uniqueKeysWithValues: tombstones.map { ($0.conversationId, $0.deletedAt) })
        var merged: [UUID: Conversation] = [:]

        for conversation in local {
            guard shouldKeep(conversation, deletedAt: deletedAt, marker: deleteAllMarker) else { continue }
            merged[conversation.id] = conversation
        }

        for cloudConversation in cloud {
            guard shouldKeep(cloudConversation, deletedAt: deletedAt, marker: deleteAllMarker) else { continue }
            if let existing = merged[cloudConversation.id] {
                // Keep the most recently updated version
                if cloudConversation.updatedAt > existing.updatedAt {
                    merged[cloudConversation.id] = cloudConversation
                }
            } else {
                merged[cloudConversation.id] = cloudConversation
            }
        }

        return Array(merged.values)
    }

    func synchronizeAvailableCloud() throws -> ConversationSyncResult {
        let local = try loadLocalConversations()
        let localTombstones = try loadTombstones()
        let cloud = try cloudSyncManager.loadConversationsFromCloud()
        let cloudTombstones = try cloudSyncManager.loadConversationTombstonesFromCloud()
        let marker = newestMarker(
            try loadDeleteAllMarker(),
            try cloudSyncManager.loadConversationDeleteAllMarkerFromCloud()
        )
        let deleteAllTombstones = marker.map { marker in
            (local + cloud).map {
                ConversationTombstone(conversationId: $0.id, deletedAt: marker.deletedAt)
            }
        } ?? []
        let tombstones = mergeTombstones(localTombstones + cloudTombstones + deleteAllTombstones)
        let conversations = mergeConversations(
            local: local,
            cloud: cloud,
            tombstones: tombstones,
            deleteAllMarker: marker
        )

        try persistLocal(conversations: conversations, tombstones: tombstones)
        try cloudSyncManager.saveConversationTombstonesToCloud(tombstones)
        if let marker {
            try cloudSyncManager.saveConversationDeleteAllMarkerToCloud(marker)
            try saveDeleteAllMarker(marker)
        }
        try cloudSyncManager.syncConversationsToCloud(conversations)
        for tombstone in tombstones {
            try cloudSyncManager.deleteConversationFromCloud(tombstone.conversationId)
        }

        var attachmentsReady = true
        for conversation in conversations {
            let isMaterialized = try cloudSyncManager.materializeAttachmentsFromCloud(for: conversation)
            attachmentsReady = isMaterialized && attachmentsReady
        }
        updateWidgetSnapshot()
        return attachmentsReady ? .synchronized : .pendingDownload
    }

    func persistLocal(conversations: [Conversation], tombstones: [ConversationTombstone]) throws {
        let ids = Set(conversations.map(\.id))
        cleanupLocalFiles(keeping: ids)
        for conversation in conversations {
            try saveLocal(conversation)
        }
        try saveTombstones(tombstones)
        for tombstone in tombstones {
            try? attachmentRepository.deleteAll(forConversationId: tombstone.conversationId)
        }
    }

    func shouldKeep(
        _ conversation: Conversation,
        deletedAt: [UUID: Date],
        marker: ConversationDeleteAllMarker?
    ) -> Bool {
        deletedAt[conversation.id] == nil
            && (marker == nil || conversation.updatedAt > marker?.deletedAt ?? .distantFuture)
    }

    func loadTombstones() throws -> [ConversationTombstone] {
        guard fileManager.fileExists(atPath: tombstonesURL.path) else { return [] }
        let data = try Data(contentsOf: tombstonesURL)
        return try JSONDecoder.iso8601.decode([ConversationTombstone].self, from: data)
    }

    func saveTombstones(_ tombstones: [ConversationTombstone]) throws {
        let data = try JSONEncoder.iso8601.encode(tombstones)
        try writeIfChanged(data, to: tombstonesURL)
    }

    func loadDeleteAllMarker() throws -> ConversationDeleteAllMarker? {
        guard fileManager.fileExists(atPath: deleteAllMarkerURL.path) else { return nil }
        let data = try Data(contentsOf: deleteAllMarkerURL)
        return try JSONDecoder.iso8601.decode(ConversationDeleteAllMarker.self, from: data)
    }

    func saveDeleteAllMarker(_ marker: ConversationDeleteAllMarker) throws {
        let data = try JSONEncoder.iso8601.encode(marker)
        try writeIfChanged(data, to: deleteAllMarkerURL)
    }

    func newestMarker(
        _ local: ConversationDeleteAllMarker?,
        _ cloud: ConversationDeleteAllMarker?
    ) -> ConversationDeleteAllMarker? {
        [local, cloud].compactMap { $0 }.max { $0.deletedAt < $1.deletedAt }
    }

    func mergedTombstones(_ adding: [ConversationTombstone]) -> [ConversationTombstone] {
        mergeTombstones(((try? loadTombstones()) ?? []) + adding)
    }

    func mergeTombstones(_ tombstones: [ConversationTombstone]) -> [ConversationTombstone] {
        var latest: [UUID: ConversationTombstone] = [:]
        for tombstone in tombstones {
            let existingDate = latest[tombstone.conversationId]?.deletedAt ?? .distantPast
            guard existingDate < tombstone.deletedAt else { continue }
            latest[tombstone.conversationId] = tombstone
        }
        return Array(latest.values)
    }

    func cleanupLocalFiles(keeping ids: Set<UUID>) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for url in fileURLs where url.pathExtension == "json" {
            if let uuid = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
               !ids.contains(uuid) {
                try? fileManager.removeItem(at: url)
                LogManager.debug("Cleaned up local conversation file: \(uuid)")
            }
        }
    }

    func writeIfChanged(_ data: Data, to url: URL) throws {
        if let existing = try? Data(contentsOf: url), existing == data { return }
        try data.write(to: url, options: .atomic)
    }

    /// Deletes all attachment files referenced by the messages of a conversation.
    func deleteAttachments(for conversation: Conversation) {
        for message in conversation.messages {
            for attachment in message.attachments {
                try? attachmentRepository.delete(attachment: attachment)
            }
        }
    }

    /// Rebuilds the App Group widget snapshot and reloads its timeline when it changed.
    func updateWidgetSnapshot(conversations: [Conversation]? = nil) {
        let conversations = conversations ?? (try? loadLocalConversations()) ?? []
        let sorted = conversations.sorted { $0.updatedAt > $1.updatedAt }
        let recentConversations = makeWidgetConversations(from: Array(sorted.prefix(6)))
        let pinnedConversations = makeWidgetConversations(from: sorted.filter(\.isPinned))
        let tags = Array(Set(conversations.flatMap(\.tags).map(\.name))).sorted()
        let recentChanged = AppGroupStore.saveConversations(recentConversations)
        let pinnedChanged = AppGroupStore.savePinnedConversations(pinnedConversations)
        let tagsChanged = AppGroupStore.saveTags(tags)
        if recentChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.conversationsWidgetKind)
        }
        if pinnedChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.pinnedConversationsWidgetKind)
        }
        if recentChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.latestConversationWidgetKind)
        }
        if tagsChanged || recentChanged || pinnedChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupStore.taggedConversationsWidgetKind)
        }
    }
}

private extension ConversationRepository {
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

// MARK: - JSONDecoder convenience

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
