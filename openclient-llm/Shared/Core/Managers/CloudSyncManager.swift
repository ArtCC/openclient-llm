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
    func allCloudConversationIds() -> Set<UUID>?
    func deleteConversationFromCloud(_ conversationId: UUID) throws
    func deleteAllFromCloud() throws
    func saveProfileToCloud(_ profile: UserProfile) throws
    func loadProfileFromCloud() throws -> UserProfile?
    func deleteProfileFromCloud() throws
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

    func allCloudConversationIds() -> Set<UUID>? {
        guard let cloudURL = cloudConversationsDirectory() else { return nil }
        guard fileManager.fileExists(atPath: cloudURL.path) else { return nil }

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: cloudURL,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return nil }

        var ids = Set<UUID>()
        for url in fileURLs {
            let name = url.lastPathComponent
            if url.pathExtension == "json",
               let uuid = UUID(uuidString: url.deletingPathExtension().lastPathComponent) {
                ids.insert(uuid)
            } else if name.hasPrefix(".") && name.hasSuffix(".json.icloud") {
                let stripped = String(name.dropFirst())
                let uuidString = stripped.replacingOccurrences(of: ".json.icloud", with: "")
                if let uuid = UUID(uuidString: uuidString) {
                    ids.insert(uuid)
                }
            }
        }
        return ids
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

    func saveProfileToCloud(_ profile: UserProfile) throws {
        guard let fileURL = cloudProfileFileURL() else { return }

        let directory = fileURL.deletingLastPathComponent()
        try ensureDirectoryExists(at: directory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profile)
        try data.write(to: fileURL, options: .atomic)
    }

    func loadProfileFromCloud() throws -> UserProfile? {
        guard let fileURL = cloudProfileFileURL() else { return nil }

        // Trigger download of iCloud placeholder if needed.
        let directory = fileURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: directory.path) {
            let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
                options: []
            )
            for url in files ?? [] where url.lastPathComponent.hasPrefix(".") && url.pathExtension == "icloud" {
                try? fileManager.startDownloadingUbiquitousItem(at: url)
            }
        }

        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func deleteProfileFromCloud() throws {
        guard let fileURL = cloudProfileFileURL() else { return }
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}

// MARK: - Private

private extension CloudSyncManager {
    func cloudConversationsDirectory() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("Conversations", isDirectory: true)
    }

    func cloudProfileFileURL() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("UserProfile.json")
    }

    func cloudDocumentsDirectory() -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    func ensureDirectoryExists(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
