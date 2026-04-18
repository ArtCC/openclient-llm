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
    func syncTemplatesToCloud(_ templates: [PromptTemplate]) throws
    func loadTemplatesFromCloud() throws -> [PromptTemplate]
    func allCloudTemplateIds() -> Set<UUID>?
    func deleteTemplateFromCloud(_ templateId: UUID) throws
    func saveMemoryToCloud(_ items: [MemoryItem]) throws
    func loadMemoryFromCloud() throws -> [MemoryItem]?
    func deleteMemoryFromCloud() throws
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

        let localDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]

        for conversation in conversations {
            let fileURL = cloudURL.appendingPathComponent("\(conversation.id.uuidString).json")
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL, options: .atomic)

            // Sync attachment files for this conversation
            try syncAttachmentFiles(for: conversation, localDocuments: localDocuments)
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
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        // Remove cloud attachment folder for this conversation
        if let cloudAttachments = cloudAttachmentsDirectory() {
            let convAttachments = cloudAttachments.appendingPathComponent(conversationId.uuidString, isDirectory: true)
            if fileManager.fileExists(atPath: convAttachments.path) {
                try fileManager.removeItem(at: convAttachments)
            }
        }
    }

    func deleteAllFromCloud() throws {
        guard let cloudURL = cloudConversationsDirectory() else { return }
        if fileManager.fileExists(atPath: cloudURL.path) {
            try fileManager.removeItem(at: cloudURL)
        }

        // Remove all cloud attachment files
        if let cloudAttachments = cloudAttachmentsDirectory(),
           fileManager.fileExists(atPath: cloudAttachments.path) {
            try fileManager.removeItem(at: cloudAttachments)
        }
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

    func syncTemplatesToCloud(_ templates: [PromptTemplate]) throws {
        guard let cloudURL = cloudTemplatesDirectory() else { return }

        try ensureDirectoryExists(at: cloudURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        for template in templates {
            let fileURL = cloudURL.appendingPathComponent("\(template.id.uuidString).json")
            let data = try encoder.encode(template)
            try data.write(to: fileURL, options: .atomic)
        }
    }

    func loadTemplatesFromCloud() throws -> [PromptTemplate] {
        guard let cloudURL = cloudTemplatesDirectory() else { return [] }
        guard fileManager.fileExists(atPath: cloudURL.path) else { return [] }

        let fileURLs = try fileManager.contentsOfDirectory(
            at: cloudURL,
            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
            options: []
        )

        for url in fileURLs where url.lastPathComponent.hasPrefix(".") && url.pathExtension == "icloud" {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var templates: [PromptTemplate] = []
        for url in fileURLs where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let template = try decoder.decode(PromptTemplate.self, from: data)
                templates.append(template)
            } catch {
                continue
            }
        }
        return templates
    }

    func allCloudTemplateIds() -> Set<UUID>? {
        guard let cloudURL = cloudTemplatesDirectory() else { return nil }
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

    func deleteTemplateFromCloud(_ templateId: UUID) throws {
        guard let cloudURL = cloudTemplatesDirectory() else { return }
        let fileURL = cloudURL.appendingPathComponent("\(templateId.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    func saveMemoryToCloud(_ items: [MemoryItem]) throws {
        guard let fileURL = cloudMemoryFileURL() else { return }

        let directory = fileURL.deletingLastPathComponent()
        try ensureDirectoryExists(at: directory)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }

    func loadMemoryFromCloud() throws -> [MemoryItem]? {
        guard let fileURL = cloudMemoryFileURL() else { return nil }

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MemoryItem].self, from: data)
    }

    func deleteMemoryFromCloud() throws {
        guard let fileURL = cloudMemoryFileURL() else { return }
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

    func cloudAttachmentsDirectory() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("Attachments", isDirectory: true)
    }

    func cloudProfileFileURL() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("UserProfile.json")
    }

    func cloudTemplatesDirectory() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("PromptTemplates", isDirectory: true)
    }

    func cloudMemoryFileURL() -> URL? {
        cloudDocumentsDirectory()?
            .appendingPathComponent("Memory.json")
    }

    func cloudDocumentsDirectory() -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    func ensureDirectoryExists(at url: URL) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Copies attachment files referenced by `conversation` from local storage to iCloud.
    func syncAttachmentFiles(for conversation: Conversation, localDocuments: URL) throws {
        guard let cloudAttachments = cloudAttachmentsDirectory() else { return }

        // Collect all attachments from all messages
        let attachments = conversation.messages.flatMap { $0.attachments }
        guard !attachments.isEmpty else { return }

        let cloudConvFolder = cloudAttachments
            .appendingPathComponent(conversation.id.uuidString, isDirectory: true)
        try ensureDirectoryExists(at: cloudConvFolder)

        for attachment in attachments where !attachment.fileRelativePath.isEmpty {
            let localFile = localDocuments.appendingPathComponent(attachment.fileRelativePath)
            guard fileManager.fileExists(atPath: localFile.path) else { continue }

            let fileName = localFile.lastPathComponent
            let cloudFile = cloudConvFolder.appendingPathComponent(fileName)

            // Skip if already synced and same size (avoid unnecessary writes)
            if fileManager.fileExists(atPath: cloudFile.path) { continue }

            try fileManager.copyItem(at: localFile, to: cloudFile)
        }
    }
}
