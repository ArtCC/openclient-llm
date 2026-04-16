//
//  AttachmentMigrationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

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

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: conversationsURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            LogManager.info("AttachmentMigrationUseCase: no conversations directory found")
            markDone()
            return
        }

        var migratedCount = 0
        for url in fileURLs where url.pathExtension == "json" {
            let conversationId = UUID(uuidString: url.deletingPathExtension().lastPathComponent)
            if migrateConversationFile(at: url, conversationId: conversationId) {
                migratedCount += 1
            }
        }

        LogManager.success("AttachmentMigrationUseCase: migrated \(migratedCount) conversations")
        markDone()
    }
}

// MARK: - Private

private extension AttachmentMigrationUseCase {
    /// Migrates a single conversation JSON file. Returns `true` if the file was modified.
    @discardableResult
    func migrateConversationFile(at url: URL, conversationId: UUID?) -> Bool {
        guard let rawData = try? Data(contentsOf: url),
              var root = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
            return false
        }

        guard var messages = root["messages"] as? [[String: Any]] else { return false }

        var didModify = false
        let folderId = conversationId ?? UUID()

        for messageIndex in messages.indices {
            guard var attachments = messages[messageIndex]["attachments"] as? [[String: Any]] else { continue }

            for attachmentIndex in attachments.indices {
                guard let updated = migrateAttachment(attachments[attachmentIndex], folderId: folderId) else {
                    continue
                }
                attachments[attachmentIndex] = updated
                didModify = true
            }

            messages[messageIndex]["attachments"] = attachments
        }

        guard didModify else { return false }

        root["messages"] = messages

        guard let updatedData = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return false }

        do {
            try updatedData.write(to: url, options: .atomic)
            return true
        } catch {
            LogManager.error("AttachmentMigrationUseCase: failed to write migrated file: \(error)")
            return false
        }
    }

    func markDone() {
        userDefaults.set(true, forKey: Self.migrationKey)
    }

    /// Migrates a single attachment dict. Returns the updated dict if migration was performed, nil otherwise.
    func migrateAttachment(_ attachment: [String: Any], folderId: UUID) -> [String: Any]? {
        // Only process legacy entries that have "data" but no "fileRelativePath"
        guard let base64String = attachment["data"] as? String,
              attachment["fileRelativePath"] == nil else { return nil }

        let rawId = attachment["id"] ?? "?"
        guard let binaryData = Data(base64Encoded: base64String) else {
            LogManager.warning("AttachmentMigrationUseCase: could not decode base64 for attachment \(rawId)")
            return nil
        }

        let attachmentId = (attachment["id"] as? String).flatMap(UUID.init) ?? UUID()
        let fileName = attachment["fileName"] as? String ?? "attachment"
        let typeRaw = attachment["type"] as? String ?? "image"
        let attachmentType = ChatMessage.AttachmentType(rawValue: typeRaw) ?? .image
        let mimeType = ChatMessage.Attachment.inferMimeType(for: attachmentType, fileName: fileName)

        let placeholder = ChatMessage.Attachment(
            id: attachmentId,
            type: attachmentType,
            fileName: fileName,
            mimeType: mimeType,
            fileRelativePath: ""
        )

        guard let relativePath = try? attachmentRepository.save(
            data: binaryData,
            for: placeholder,
            conversationId: folderId
        ) else {
            LogManager.error("AttachmentMigrationUseCase: failed to save attachment \(attachmentId)")
            return nil
        }

        var updated = attachment
        updated.removeValue(forKey: "data")
        updated["fileRelativePath"] = relativePath
        updated["mimeType"] = mimeType
        LogManager.debug("AttachmentMigrationUseCase: migrated attachment \(attachmentId) → \(relativePath)")
        return updated
    }
}
