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
    func hasPendingConversationDownloads() throws -> Bool
    func materializeAttachmentsFromCloud(for conversation: Conversation) throws -> Bool
    func loadConversationTombstonesFromCloud() throws -> [ConversationTombstone]
    func saveConversationTombstonesToCloud(_ tombstones: [ConversationTombstone]) throws
    func loadConversationDeleteAllMarkerFromCloud() throws -> ConversationDeleteAllMarker?
    func saveConversationDeleteAllMarkerToCloud(_ marker: ConversationDeleteAllMarker) throws
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

    let fileManager: FileManager

    // MARK: - Init

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Public

    func isCloudAvailable() -> Bool {
        fileManager.ubiquityIdentityToken != nil && cloudDocumentsDirectory() != nil
    }

    func syncConversationsToCloud(_ conversations: [Conversation]) throws {
        guard let cloudURL = cloudConversationsDirectory() else { return }
        try ensureDirectoryExists(at: cloudURL)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let localDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for conversation in conversations {
            let fileURL = cloudURL.appendingPathComponent("\(conversation.id.uuidString).json")
            let data = try encoder.encode(conversation)
            try writeIfChanged(data, to: fileURL)
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
                LogManager.error("Failed to decode cloud conversation \(url.lastPathComponent): \(error)")
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

        let placeholderURL = cloudURL.appendingPathComponent(".\(conversationId.uuidString).json.icloud")
        if fileManager.fileExists(atPath: placeholderURL.path) {
            try fileManager.removeItem(at: placeholderURL)
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

    func hasPendingConversationDownloads() throws -> Bool {
        guard let cloudURL = cloudConversationsDirectory(), fileManager.fileExists(atPath: cloudURL.path) else {
            return false
        }
        let files = try fileManager.contentsOfDirectory(at: cloudURL, includingPropertiesForKeys: nil, options: [])
        let placeholders = files.filter { $0.lastPathComponent.hasPrefix(".") && $0.pathExtension == "icloud" }
        for placeholder in placeholders {
            try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
        }
        guard placeholders.isEmpty else { return true }
        let conversationFiles = files.filter { $0.pathExtension == "json" }
        let conversationsPending = try conversationFiles.contains { try requiresDownload(at: $0) }
        let tombstonesPending = try tombstonesRequireDownload()
        return conversationsPending || tombstonesPending
    }

    func materializeAttachmentsFromCloud(for conversation: Conversation) throws -> Bool {
        guard let cloudAttachments = cloudAttachmentsDirectory() else { return false }
        let localDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cloudFolder = cloudAttachments.appendingPathComponent(conversation.id.uuidString, isDirectory: true)
        var completed = true

        for attachment in conversation.messages.flatMap(\.attachments) where !attachment.fileRelativePath.isEmpty {
            let localFile = localDocuments.appendingPathComponent(attachment.fileRelativePath)
            guard !fileManager.fileExists(atPath: localFile.path) else { continue }
            let cloudFile = cloudFolder.appendingPathComponent(localFile.lastPathComponent)
            let placeholder = cloudFolder.appendingPathComponent(".\(localFile.lastPathComponent).icloud")
            if fileManager.fileExists(atPath: placeholder.path) {
                try? fileManager.startDownloadingUbiquitousItem(at: placeholder)
                completed = false
                continue
            }
            guard fileManager.fileExists(atPath: cloudFile.path) else {
                completed = false
                continue
            }
            try ensureDirectoryExists(at: localFile.deletingLastPathComponent())
            try fileManager.copyItem(at: cloudFile, to: localFile)
        }
        return completed
    }

    func loadConversationTombstonesFromCloud() throws -> [ConversationTombstone] {
        var tombstones: [ConversationTombstone] = []
        if let legacyURL = cloudConversationTombstonesFileURL(), fileManager.fileExists(atPath: legacyURL.path) {
            tombstones += try decodeTombstones(at: legacyURL)
        }
        if let directory = cloudConversationTombstonesDirectory(), fileManager.fileExists(atPath: directory.path) {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            tombstones += try files.filter { $0.pathExtension == "json" }.map { try decodeTombstone(at: $0) }
        }
        return tombstones
    }

    func saveConversationTombstonesToCloud(_ tombstones: [ConversationTombstone]) throws {
        guard let directory = cloudConversationTombstonesDirectory() else { return }
        try ensureDirectoryExists(at: directory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for tombstone in tombstones {
            let fileURL = directory.appendingPathComponent("\(tombstone.conversationId.uuidString).json")
            try writeIfChanged(encoder.encode(tombstone), to: fileURL)
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
