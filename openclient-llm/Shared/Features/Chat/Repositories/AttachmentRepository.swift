//
//  AttachmentRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Protocol

nonisolated protocol AttachmentRepositoryProtocol: Sendable {
    /// Persists `data` for `attachment` inside the given conversation folder and returns
    /// the relative path that was stored in `attachment.fileRelativePath`.
    /// - Returns: The relative path `"Attachments/<conversationId>/<attachmentId>.<ext>"`
    @discardableResult
    func save(data: Data, for attachment: ChatMessage.Attachment, conversationId: UUID) throws -> String

    /// Loads the raw bytes for `attachment`.
    func load(attachment: ChatMessage.Attachment) throws -> Data

    /// Deletes the file on disk for a single `attachment`.
    func delete(attachment: ChatMessage.Attachment) throws

    /// Deletes all attachment files for a given conversation.
    func deleteAll(forConversationId conversationId: UUID) throws

    /// Deletes every attachment across all conversations (nuclear reset).
    func deleteAll() throws
}

// MARK: - AttachmentRepository

// Safety: FileManager is thread-safe per Apple documentation. All stored properties are immutable (`let`).
nonisolated struct AttachmentRepository: AttachmentRepositoryProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let fileManager: FileManager
    private let baseURL: URL
    private let fileResolver: AttachmentFileResolver

    // MARK: - Init

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        let baseURL = baseURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.baseURL = baseURL
        self.fileResolver = AttachmentFileResolver(fileManager: fileManager, baseURL: baseURL)
    }

    // MARK: - Public

    @discardableResult
    func save(data: Data, for attachment: ChatMessage.Attachment, conversationId: UUID) throws -> String {
        let relativePath = ConversationAttachmentPath.relativePath(
            for: attachment,
            conversationId: conversationId
        )
        _ = try resolvedURL(for: relativePath)
        let fileURL = baseURL.appendingPathComponent(relativePath)

        try ensureDirectoryExists(for: fileURL)
        let resolvedURL = try resolvedURL(for: relativePath)
        try data.write(to: resolvedURL, options: .atomic)
        guard try Data(contentsOf: resolvedURL) == data else {
            throw AttachmentRepositoryError.fileNotFound
        }

        LogManager.debug("AttachmentRepository.save completed bytes=\(data.count)")
        return relativePath
    }

    func load(attachment: ChatMessage.Attachment) throws -> Data {
        let fileURL = try attachmentURL(for: attachment)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            LogManager.error("AttachmentRepository.load failed reason=fileNotFound")
            throw AttachmentRepositoryError.fileNotFound
        }
        return try Data(contentsOf: fileURL)
    }

    func delete(attachment: ChatMessage.Attachment) throws {
        let fileURL = try attachmentURL(for: attachment)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
        LogManager.debug("AttachmentRepository.delete completed")
    }

    func deleteAll(forConversationId conversationId: UUID) throws {
        let dirURL: URL
        do {
            dirURL = try fileResolver.conversationDirectory(conversationId)
        } catch {
            throw AttachmentRepositoryError.invalidPath
        }
        guard fileManager.fileExists(atPath: dirURL.path) else { return }
        try fileManager.removeItem(at: dirURL)
        LogManager.debug("AttachmentRepository.deleteAll conversationId=\(conversationId)")
    }

    func deleteAll() throws {
        let dirURL: URL
        do {
            dirURL = try fileResolver.attachmentRoot()
        } catch {
            throw AttachmentRepositoryError.invalidPath
        }
        guard fileManager.fileExists(atPath: dirURL.path) else { return }
        try fileManager.removeItem(at: dirURL)
        LogManager.warning("AttachmentRepository.deleteAll — all attachments removed")
    }
}

// MARK: - Private

private extension AttachmentRepository {
    func ensureDirectoryExists(for fileURL: URL) throws {
        let dirURL = fileURL.deletingLastPathComponent()
        guard !fileManager.fileExists(atPath: dirURL.path) else { return }
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
    }

    func attachmentURL(for attachment: ChatMessage.Attachment) throws -> URL {
        let key: CloudAttachmentKey
        do {
            guard let value = try ConversationAttachmentPath.key(for: attachment) else {
                throw AttachmentRepositoryError.invalidPath
            }
            key = value
        } catch {
            throw AttachmentRepositoryError.invalidPath
        }
        return try resolvedURL(for: ConversationAttachmentPath.relativePath(for: key))
    }

    func resolvedURL(for relativePath: String) throws -> URL {
        do {
            return try fileResolver.resolve(relativePath: relativePath)
        } catch {
            throw AttachmentRepositoryError.invalidPath
        }
    }
}

// MARK: - AttachmentRepositoryError

nonisolated enum AttachmentRepositoryError: LocalizedError {
    case fileNotFound
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            String(localized: "The attachment file could not be found.")
        case .invalidPath:
            String(localized: "The attachment file path is invalid.")
        }
    }
}
