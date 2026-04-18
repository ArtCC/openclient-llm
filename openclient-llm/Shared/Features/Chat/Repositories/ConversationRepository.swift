//
//  ConversationRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ConversationRepositoryProtocol: Sendable {
    func loadAll() throws -> [Conversation]
    func save(_ conversation: Conversation) throws
    func delete(_ conversationId: UUID) throws
    func deleteAll() throws
}

struct ConversationRepository: ConversationRepositoryProtocol {
    // MARK: - Properties

    private let fileManager: FileManager
    private let directoryURL: URL
    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        attachmentRepository: AttachmentRepositoryProtocol = AttachmentRepository()
    ) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directoryURL = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.attachmentRepository = attachmentRepository
    }

    // MARK: - Public

    func loadAll() throws -> [Conversation] {
        LogManager.debug("loadAll conversations")
        try ensureDirectoryExists()

        var localConversations = try loadLocalConversations()

        if settingsManager.getIsCloudSyncEnabled() {
            let cloudConversations = (try? cloudSyncManager.loadConversationsFromCloud()) ?? []
            let cloudIds = cloudSyncManager.allCloudConversationIds()

            localConversations = mergeConversations(
                local: localConversations,
                cloud: cloudConversations,
                cloudIds: cloudIds
            )

            // Clean up local files for conversations removed from cloud
            if cloudIds != nil {
                let mergedIds = Set(localConversations.map(\.id))
                cleanupLocalFiles(keeping: mergedIds)
            }

            // Persist merged result locally
            for conversation in localConversations {
                try saveLocal(conversation)
            }
        }

        let sorted = localConversations.sorted { $0.updatedAt > $1.updatedAt }
        LogManager.success("loadAll returned \(sorted.count) conversations")
        return sorted
    }

    func save(_ conversation: Conversation) throws {
        LogManager.debug("save conversation id=\(conversation.id) title='\(conversation.title)'")
        try ensureDirectoryExists()
        try saveLocal(conversation)

        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.syncConversationsToCloud([conversation])
        }
    }

    func delete(_ conversationId: UUID) throws {
        LogManager.debug("delete conversation id=\(conversationId)")
        // Load conversation before deleting so we can clean up its attachment files
        let fileURL = directoryURL.appendingPathComponent("\(conversationId.uuidString).json")
        if let data = try? Data(contentsOf: fileURL),
           let conversation = try? JSONDecoder.iso8601.decode(Conversation.self, from: data) {
            deleteAttachments(for: conversation)
        }
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
        LogManager.success("delete conversation id=\(conversationId) done")

        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.deleteConversationFromCloud(conversationId)
        }
    }

    func deleteAll() throws {
        LogManager.warning("deleteAll conversations")
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
        try ensureDirectoryExists()
        try? attachmentRepository.deleteAll()
        LogManager.success("deleteAll conversations done")

        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.deleteAllFromCloud()
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
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(conversation)
        let fileURL = directoryURL.appendingPathComponent("\(conversation.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
    }

    /// Merges local and cloud conversations.
    /// When `cloudIds` is provided (cloud directory exists), only local conversations
    /// whose ID appears in the cloud set are kept — the cloud is the source of truth.
    /// When `cloudIds` is nil (cloud directory unreachable), all local conversations are kept.
    func mergeConversations(
        local: [Conversation],
        cloud: [Conversation],
        cloudIds: Set<UUID>?
    ) -> [Conversation] {
        var merged: [UUID: Conversation] = [:]

        for conversation in local {
            if let cloudIds {
                guard cloudIds.contains(conversation.id) else { continue }
            }
            merged[conversation.id] = conversation
        }

        for cloudConversation in cloud {
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

    /// Deletes all attachment files referenced by the messages of a conversation.
    func deleteAttachments(for conversation: Conversation) {
        for message in conversation.messages {
            for attachment in message.attachments {
                try? attachmentRepository.delete(attachment: attachment)
            }
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
