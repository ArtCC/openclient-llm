//
//  CloudSyncManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol CloudSyncManagerProtocol: Sendable {
    func isCloudAvailable() -> Bool
    func syncConversationsToCloud(_ conversations: [Conversation]) throws
    func loadConversationsFromCloud() throws -> [Conversation]
    func deleteConversationFromCloud(_ conversationId: UUID) throws
    func deleteAllFromCloud() throws
}

struct CloudSyncManager: CloudSyncManagerProtocol, Sendable {
    // MARK: - Properties

    private let fileManager: FileManager

    // MARK: - Init

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Public

    func isCloudAvailable() -> Bool {
        fileManager.ubiquityIdentityToken != nil
    }

    func syncConversationsToCloud(_ conversations: [Conversation]) throws {
        guard let cloudURL = cloudConversationsDirectory() else { return }

        try ensureDirectoryExists(at: cloudURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        for conversation in conversations {
            let fileURL = cloudURL.appendingPathComponent("\(conversation.id.uuidString).json")
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL, options: .atomic)
        }
    }

    func loadConversationsFromCloud() throws -> [Conversation] {
        guard let cloudURL = cloudConversationsDirectory() else { return [] }
        guard fileManager.fileExists(atPath: cloudURL.path) else { return [] }

        // Do NOT skip hidden files: iCloud placeholders are named `.UUID.json.icloud`
        // (leading dot = hidden). We need to see them to trigger their download.
        let fileURLs = try fileManager.contentsOfDirectory(
            at: cloudURL,
            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
            options: []
        )

        // Trigger download of any cloud-only placeholder files so they are available
        // on the next refresh cycle (download is asynchronous).
        for url in fileURLs where url.lastPathComponent.hasPrefix(".") && url.pathExtension == "icloud" {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
        }

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

        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func deleteConversationFromCloud(_ conversationId: UUID) throws {
        guard let cloudURL = cloudConversationsDirectory() else { return }
        let fileURL = cloudURL.appendingPathComponent("\(conversationId.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    func deleteAllFromCloud() throws {
        guard let cloudURL = cloudConversationsDirectory() else { return }
        guard fileManager.fileExists(atPath: cloudURL.path) else { return }
        try fileManager.removeItem(at: cloudURL)
    }
}

// MARK: - Private

private extension CloudSyncManager {
    func cloudConversationsDirectory() -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Conversations", isDirectory: true)
    }

    func ensureDirectoryExists(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
