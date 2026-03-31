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

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager()
    ) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directoryURL = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
    }

    // MARK: - Public

    func loadAll() throws -> [Conversation] {
        try ensureDirectoryExists()

        var localConversations = try loadLocalConversations()

        if settingsManager.getIsCloudSyncEnabled() {
            let cloudConversations = (try? cloudSyncManager.loadConversationsFromCloud()) ?? []
            localConversations = mergeConversations(local: localConversations, cloud: cloudConversations)

            // Persist merged result locally
            for conversation in localConversations {
                try saveLocal(conversation)
            }
        }

        return localConversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ conversation: Conversation) throws {
        try ensureDirectoryExists()
        try saveLocal(conversation)

        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.syncConversationsToCloud([conversation])
        }
    }

    func delete(_ conversationId: UUID) throws {
        let fileURL = directoryURL.appendingPathComponent("\(conversationId.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)

        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.deleteConversationFromCloud(conversationId)
        }
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
        try ensureDirectoryExists()

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

    func mergeConversations(local: [Conversation], cloud: [Conversation]) -> [Conversation] {
        var merged: [UUID: Conversation] = [:]

        for conversation in local {
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
}
