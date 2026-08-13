//
//  AttachmentMigrationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CryptoKit
import Foundation

// MARK: - Protocol

protocol AttachmentMigrationUseCaseProtocol: Sendable {
    /// Migrates legacy conversations that store attachment data inline in JSON (pre-v2 format)
    /// to the new disk-based format. Safe to call multiple times — runs only once per install.
    func execute()
}

// MARK: - AttachmentMigrationUseCase

/// One-shot migration that reads each `Conversations/<UUID>.json`, finds attachment objects
/// that contain a base64 `"data"` key (legacy format), writes the binary to disk via
/// `AttachmentRepository`, replaces `"data"` with `"fileRelativePath"` and `"mimeType"`,
/// then re-writes the JSON. A `UserDefaults` flag prevents repeat runs.
struct AttachmentMigrationUseCase: AttachmentMigrationUseCaseProtocol {
    // MARK: - Properties

    private static let migrationKey = "attachmentMigrationV1Done"

    private let fileManager: FileManager
    private let attachmentRepository: AttachmentRepositoryProtocol
    private let userDefaults: UserDefaults
    private let baseDirectory: URL

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        attachmentRepository: AttachmentRepositoryProtocol = AttachmentRepository(),
        userDefaults: UserDefaults = .standard,
        baseDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.attachmentRepository = attachmentRepository
        self.userDefaults = userDefaults
        self.baseDirectory = baseDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Public

    func execute() {
        guard !userDefaults.bool(forKey: Self.migrationKey) else {
            LogManager.debug("AttachmentMigrationUseCase: already completed, skipping")
            return
        }

        LogManager.info("AttachmentMigrationUseCase: starting migration")
        let conversationsURL = baseDirectory.appendingPathComponent("Conversations", isDirectory: true)
        guard fileManager.fileExists(atPath: conversationsURL.path) else {
            LogManager.info("AttachmentMigrationUseCase: no conversations directory found")
            markDone()
            return
        }

        let fileURLs: [URL]
        do {
            let values = try conversationsURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                LogManager.error("AttachmentMigrationUseCase: conversations path is not a directory")
                return
            }
            fileURLs = try fileManager.contentsOfDirectory(
                at: conversationsURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
        } catch {
            LogManager.error("AttachmentMigrationUseCase: failed to enumerate conversations")
            return
        }

        var migratedCount = 0
        var hasFailure = false
        for url in fileURLs where url.pathExtension == "json" {
            let conversationId = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            switch migrateConversationFile(at: url, conversationId: conversationId) {
            case .migrated:
                migratedCount += 1
            case .failed:
                hasFailure = true
            case .unchanged:
                break
            }
        }

        LogManager.success("AttachmentMigrationUseCase: migrated \(migratedCount) conversations")
        if !hasFailure {
            markDone()
        }
    }
}

// MARK: - Private

private extension AttachmentMigrationUseCase {
    enum MigrationResult {
        case unchanged
        case migrated
        case failed
    }

    struct MessageMigration {
        let messages: [[String: Any]]
        let attachments: [PlannedAttachment]
        let hasFailure: Bool
    }

    struct PlannedAttachment {
        let attachment: ChatMessage.Attachment
        let data: Data
        let relativePath: String
    }

    func migrateConversationFile(at url: URL, conversationId: UUID?) -> MigrationResult {
        guard let rawData = try? Data(contentsOf: url),
              var root = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
            return .failed
        }

        guard let messages = root["messages"] as? [[String: Any]] else { return .failed }
        guard let folderId = conversationId
            ?? (root["id"] as? String).flatMap(UUID.init(uuidString:)) else {
            return .failed
        }
        if containsLegacyAttachment(in: messages),
           !preserveForRecovery(rawData, conversationId: folderId) {
            return .failed
        }

        let migration = planMessages(messages, folderId: folderId)
        guard !migration.attachments.isEmpty else { return migration.hasFailure ? .failed : .unchanged }
        guard !migration.hasFailure else { return .failed }
        guard preflight(migration.attachments), persist(migration.attachments, folderId: folderId) else {
            return .failed
        }
        root["messages"] = migration.messages

        guard let updatedData = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return .failed }

        do {
            try updatedData.write(to: url, options: .atomic)
            guard try Data(contentsOf: url) == updatedData,
                  verifyMigratedData(
                    updatedData,
                    conversationId: folderId,
                    migratedAttachments: migration.attachments
                  ) else {
                try rawData.write(to: url, options: .atomic)
                return .failed
            }
            return .migrated
        } catch {
            LogManager.error("AttachmentMigrationUseCase: failed to write migrated file: \(error)")
            return .failed
        }
    }

    func markDone() {
        userDefaults.set(true, forKey: Self.migrationKey)
    }

    func planMessages(_ source: [[String: Any]], folderId: UUID) -> MessageMigration {
        var messages = source
        var plannedAttachments: [PlannedAttachment] = []
        var hasFailure = false
        for messageIndex in messages.indices {
            guard var attachments = messages[messageIndex]["attachments"] as? [[String: Any]] else { continue }
            for attachmentIndex in attachments.indices {
                let attachment = attachments[attachmentIndex]
                guard attachment["data"] != nil, attachment["fileRelativePath"] == nil else { continue }
                guard let planned = plannedAttachment(attachment, folderId: folderId) else {
                    hasFailure = true
                    continue
                }
                var updated = attachment
                updated.removeValue(forKey: "data")
                updated["fileRelativePath"] = planned.relativePath
                updated["mimeType"] = planned.attachment.mimeType
                attachments[attachmentIndex] = updated
                plannedAttachments.append(planned)
            }
            messages[messageIndex]["attachments"] = attachments
        }
        return MessageMigration(messages: messages, attachments: plannedAttachments, hasFailure: hasFailure)
    }

    func containsLegacyAttachment(in messages: [[String: Any]]) -> Bool {
        messages.contains { message in
            guard let attachments = message["attachments"] as? [[String: Any]] else { return false }
            return attachments.contains { $0["data"] != nil && $0["fileRelativePath"] == nil }
        }
    }

    func preserveForRecovery(_ data: Data, conversationId: UUID) -> Bool {
        let directory = baseDirectory
            .appendingPathComponent("ConversationRecovery/Migrations/Attachments", isDirectory: true)
        let digest = SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
        let url = directory.appendingPathComponent("\(conversationId.uuidString)-\(digest).json")
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: url.path) {
                try data.write(to: url, options: .atomic)
            }
            return try Data(contentsOf: url) == data
        } catch {
            return false
        }
    }

    func verifyMigratedData(
        _ data: Data,
        conversationId: UUID,
        migratedAttachments: [PlannedAttachment]
    ) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["id"] as? String).flatMap(UUID.init(uuidString:)) == conversationId,
              let messages = root["messages"] as? [[String: Any]] else {
            return false
        }
        guard messages.allSatisfy({ message in
            guard let attachments = message["attachments"] as? [[String: Any]] else { return true }
            return attachments.allSatisfy { attachment in
                guard attachment["data"] == nil,
                      let path = attachment["fileRelativePath"] as? String else { return false }
                let components = (path as NSString).pathComponents
                return components.count == 3
                    && components[0] == "Attachments"
                    && UUID(uuidString: components[1]) == conversationId
            }
        }) else { return false }
        return migratedAttachments.allSatisfy { planned in
            (try? attachmentRepository.load(attachment: planned.attachment)) == planned.data
        }
    }

    func plannedAttachment(_ attachment: [String: Any], folderId: UUID) -> PlannedAttachment? {
        guard let base64String = attachment["data"] as? String,
              attachment["fileRelativePath"] == nil else { return nil }

        let rawId = attachment["id"] ?? "?"
        guard let binaryData = Data(base64Encoded: base64String) else {
            LogManager.warning("AttachmentMigrationUseCase: could not decode base64 for attachment \(rawId)")
            return nil
        }

        guard let attachmentId = (attachment["id"] as? String).flatMap(UUID.init) else {
            LogManager.warning("AttachmentMigrationUseCase: invalid attachment identifier")
            return nil
        }
        let fileName = attachment["fileName"] as? String ?? "attachment"
        let typeRaw = attachment["type"] as? String ?? "image"
        let attachmentType = ChatMessage.AttachmentType(rawValue: typeRaw) ?? .image
        let mimeType = ChatMessage.Attachment.inferMimeType(for: attachmentType, fileName: fileName)

        let relativePath = ConversationAttachmentPath.relativePath(
            for: ChatMessage.Attachment(
                id: attachmentId,
                type: attachmentType,
                fileName: fileName,
                mimeType: mimeType,
                fileRelativePath: ""
            ),
            conversationId: folderId
        )
        let persistedAttachment = ChatMessage.Attachment(
            id: attachmentId,
            type: attachmentType,
            fileName: fileName,
            mimeType: mimeType,
            fileRelativePath: relativePath
        )
        return PlannedAttachment(attachment: persistedAttachment, data: binaryData, relativePath: relativePath)
    }

    func preflight(_ attachments: [PlannedAttachment]) -> Bool {
        var dataByPath: [String: Data] = [:]
        let resolver = AttachmentFileResolver(fileManager: fileManager, baseURL: baseDirectory)
        for planned in attachments {
            if let existing = dataByPath[planned.relativePath], existing != planned.data {
                return false
            }
            dataByPath[planned.relativePath] = planned.data
            do {
                let url = try resolver.resolve(relativePath: planned.relativePath)
                if fileManager.fileExists(atPath: url.path), try Data(contentsOf: url) != planned.data {
                    return false
                }
            } catch {
                return false
            }
        }
        return true
    }

    func persist(_ attachments: [PlannedAttachment], folderId: UUID) -> Bool {
        for planned in attachments {
            guard let savedPath = try? attachmentRepository.save(
                data: planned.data,
                for: planned.attachment,
                conversationId: folderId
            ), savedPath == planned.relativePath,
            (try? attachmentRepository.load(attachment: planned.attachment)) == planned.data else {
                LogManager.error("AttachmentMigrationUseCase: failed to persist attachment")
                return false
            }
        }
        return true
    }
}
