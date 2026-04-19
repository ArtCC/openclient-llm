//
//  SendFileToChatIntent.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents
import Foundation
import UniformTypeIdentifiers

// MARK: - OpenClientIntentError

enum OpenClientIntentError: LocalizedError {
    case unsupportedFileType
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return String(localized: "Only images and PDFs are supported")
        case .fileWriteFailed:
            return String(localized: "Could not write file to the shared container")
        }
    }
}

// MARK: - SendFileToChatIntent

/// AppIntent that receives an image or PDF file from Apple Shortcuts and opens
/// OpenClient with that file already attached to a new conversation.
///
/// Routing: writes the file to the App Group container via `ShareExtensionStore`,
/// then sets `ShareManager.hasPendingShare = true`. `HomeViewModel` picks this up
/// through the existing Share Extension flow, creating a new conversation with the
/// attachment pre-loaded — identical to sharing from Files or Safari.
struct SendFileToChatIntent: AppIntent {
    // MARK: - Metadata

    nonisolated static let title: LocalizedStringResource = "Send File to Chat"
    nonisolated static let description = IntentDescription(
        "Sends an image or PDF to a new OpenClient conversation."
    )
    nonisolated static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(title: "File")
    var file: IntentFile

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        let fileType = file.type
        let isImage = fileType?.conforms(to: .image) ?? false
        let isPDF = fileType?.conforms(to: .pdf) ?? false

        guard isImage || isPDF else {
            throw OpenClientIntentError.unsupportedFileType
        }

        let mimeType = fileType?.preferredMIMEType ?? (isImage ? "image/jpeg" : "application/pdf")
        let fileData = file.data

        do {
            try await MainActor.run {
                let relativePath = try ShareExtensionStore.writeAttachmentData(fileData, fileName: file.filename)
                let attachment = ShareExtensionItem.Attachment(
                    fileName: file.filename,
                    mimeType: mimeType,
                    relativePath: relativePath
                )
                let item = ShareExtensionItem(
                    text: nil,
                    url: nil,
                    attachments: [attachment],
                    createdAt: Date()
                )
                try ShareExtensionStore.save(item)
            }
        } catch {
            throw OpenClientIntentError.fileWriteFailed
        }

        await MainActor.run {
            ShareManager.shared.hasPendingShare = true
        }

        return .result()
    }
}
