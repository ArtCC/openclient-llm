//
//  AttachmentRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Protocol

protocol AttachmentRepositoryProtocol: Sendable {
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

struct AttachmentRepository: AttachmentRepositoryProtocol {
    // MARK: - Properties

    private let fileManager: FileManager
    private let baseURL: URL

    // MARK: - Init

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.baseURL = documentsURL
    }

    // MARK: - Public

    @discardableResult
    func save(data: Data, for attachment: ChatMessage.Attachment, conversationId: UUID) throws -> String {
        let ext = fileExtension(for: attachment.mimeType, fallback: attachment.fileName)
        let relativePath = "Attachments/\(conversationId.uuidString)/\(attachment.id.uuidString).\(ext)"
        let fileURL = baseURL.appendingPathComponent(relativePath)

        try ensureDirectoryExists(for: fileURL)
        try data.write(to: fileURL, options: .atomic)

        LogManager.debug("AttachmentRepository.save \(relativePath) (\(data.count) bytes)")
        return relativePath
    }

    func load(attachment: ChatMessage.Attachment) throws -> Data {
        let fileURL = baseURL.appendingPathComponent(attachment.fileRelativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            LogManager.error("AttachmentRepository.load: file not found \(attachment.fileRelativePath)")
            throw AttachmentRepositoryError.fileNotFound(attachment.fileRelativePath)
        }
        return try Data(contentsOf: fileURL)
    }

    func delete(attachment: ChatMessage.Attachment) throws {
        let fileURL = baseURL.appendingPathComponent(attachment.fileRelativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
        LogManager.debug("AttachmentRepository.delete \(attachment.fileRelativePath)")
    }

    func deleteAll(forConversationId conversationId: UUID) throws {
        let dirURL = baseURL.appendingPathComponent("Attachments/\(conversationId.uuidString)", isDirectory: true)
        guard fileManager.fileExists(atPath: dirURL.path) else { return }
        try fileManager.removeItem(at: dirURL)
        LogManager.debug("AttachmentRepository.deleteAll conversationId=\(conversationId)")
    }

    func deleteAll() throws {
        let dirURL = baseURL.appendingPathComponent("Attachments", isDirectory: true)
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

    /// Derives a file extension from MIME type, with a fallback to the original file name extension.
    func fileExtension(for mimeType: String, fallback fileName: String) -> String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png":  return "png"
        case "image/gif":  return "gif"
        case "image/webp": return "webp"
        case "application/pdf": return "pdf"
        default:
            let ext = (fileName as NSString).pathExtension.lowercased()
            return ext.isEmpty ? "bin" : ext
        }
    }
}

// MARK: - AttachmentRepositoryError

enum AttachmentRepositoryError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Attachment file not found at path: \(path)"
        }
    }
}
