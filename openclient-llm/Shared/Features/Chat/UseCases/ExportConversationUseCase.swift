//
//  ExportConversationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ExportConversationUseCaseProtocol: Sendable {
    func execute(_ conversation: Conversation) throws -> Data
}

/// Exports a conversation to a self-contained JSON file.
///
/// Attachment files stored on disk are loaded and embedded as base64 `"data"` strings
/// so the exported file is portable and can be imported on another device.
struct ExportConversationUseCase: ExportConversationUseCaseProtocol {
    // MARK: - Properties

    private let attachmentRepository: AttachmentRepositoryProtocol

    // MARK: - Init

    init(attachmentRepository: AttachmentRepositoryProtocol = AttachmentRepository()) {
        self.attachmentRepository = attachmentRepository
    }

    // MARK: - Execute

    func execute(_ conversation: Conversation) throws -> Data {
        // Build a mutable JSON dictionary so we can inject attachment data inline.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let conversationData = try encoder.encode(conversation)
        guard var root = try JSONSerialization.jsonObject(with: conversationData) as? [String: Any],
              var messages = root["messages"] as? [[String: Any]] else {
            return conversationData
        }

        var didModify = false

        for messageIndex in messages.indices {
            guard var attachments = messages[messageIndex]["attachments"] as? [[String: Any]] else { continue }

            for attachmentIndex in attachments.indices {
                var attachment = attachments[attachmentIndex]

                // Re-embed binary data for portability
                guard let relativePath = attachment["fileRelativePath"] as? String,
                      !relativePath.isEmpty else { continue }

                // Build a minimal Attachment to load from repository
                let attachmentId = (attachment["id"] as? String).flatMap(UUID.init) ?? UUID()
                let fileName = attachment["fileName"] as? String ?? "attachment"
                let typeRaw = attachment["type"] as? String ?? "image"
                let attachmentType = ChatMessage.AttachmentType(rawValue: typeRaw) ?? .image
                let mimeType = attachment["mimeType"] as? String
                    ?? ChatMessage.Attachment.inferMimeType(for: attachmentType, fileName: fileName)

                let placeholder = ChatMessage.Attachment(
                    id: attachmentId,
                    type: attachmentType,
                    fileName: fileName,
                    mimeType: mimeType,
                    fileRelativePath: relativePath
                )

                guard let binaryData = try? attachmentRepository.load(attachment: placeholder) else { continue }

                attachment["data"] = binaryData.base64EncodedString()
                attachments[attachmentIndex] = attachment
                didModify = true
            }

            messages[messageIndex]["attachments"] = attachments
        }

        guard didModify else { return conversationData }

        root["messages"] = messages
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
}
