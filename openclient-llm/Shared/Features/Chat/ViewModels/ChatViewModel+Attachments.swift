//
//  ChatViewModel+Attachments.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Attachments

extension ChatViewModel {
    func addAttachment(data: Data, fileName: String, type: ChatMessage.AttachmentType) {
        switch type {
        case .image:
            prepareImageAttachment(data: data, fileName: fileName)
        case .pdf:
            storeAttachment(data: data, fileName: fileName, type: type, mimeType: "application/pdf")
        }
    }

    func removeAttachment(_ id: UUID) {
        guard case .loaded(var loadedState) = state else { return }
        if !isPrivateChat,
           let attachment = loadedState.pendingAttachments.first(where: { $0.id == id }) {
            try? attachmentRepository.delete(attachment: attachment)
        }
        loadedState.pendingAttachments.removeAll { $0.id == id }
        state = .loaded(loadedState)
    }
}

// MARK: - Private

private extension ChatViewModel {
    func prepareImageAttachment(data: Data, fileName: String) {
        guard case .loaded(var loadedState) = state else { return }
        let contextId = loadedState.conversation?.id ?? loadedState.pendingSessionId
        attachmentPreparationCount += 1
        loadedState.isPreparingAttachment = true
        state = .loaded(loadedState)

        Task {
            do {
                let prepared = try await prepareImageAttachmentUseCase.execute(data: data, fileName: fileName)
                guard isCurrentAttachmentContext(contextId) else {
                    finishPreparingAttachment()
                    return
                }
                storeAttachment(
                    data: prepared.data,
                    fileName: prepared.fileName,
                    type: .image,
                    mimeType: prepared.mimeType
                )
                finishPreparingAttachment()
            } catch {
                LogManager.error("prepareImageAttachment failed: \(error)")
                finishPreparingAttachment(
                    errorMessage: isCurrentAttachmentContext(contextId) ? error.localizedDescription : nil
                )
            }
        }
    }

    func storeAttachment(
        data: Data,
        fileName: String,
        type: ChatMessage.AttachmentType,
        mimeType: String
    ) {
        guard case .loaded(var loadedState) = state else { return }
        if isPrivateChat {
            loadedState.pendingAttachments.append(ChatMessage.Attachment(
                type: type,
                fileName: fileName,
                mimeType: mimeType,
                fileRelativePath: "",
                transientData: data
            ))
            state = .loaded(loadedState)
            return
        }
        let folderId = loadedState.conversation?.id ?? loadedState.pendingSessionId
        let attachmentId = UUID()
        let placeholder = ChatMessage.Attachment(
            id: attachmentId,
            type: type,
            fileName: fileName,
            mimeType: mimeType,
            fileRelativePath: ""
        )
        do {
            let relativePath = try attachmentRepository.save(data: data, for: placeholder, conversationId: folderId)
            let saved = ChatMessage.Attachment(
                id: attachmentId,
                type: type,
                fileName: fileName,
                mimeType: mimeType,
                fileRelativePath: relativePath
            )
            loadedState.pendingAttachments.append(saved)
            state = .loaded(loadedState)
        } catch {
            LogManager.error("addAttachment failed to save to disk: \(error)")
        }
    }

    func finishPreparingAttachment(errorMessage: String? = nil) {
        attachmentPreparationCount = max(attachmentPreparationCount - 1, 0)
        guard case .loaded(var loadedState) = state else { return }
        loadedState.isPreparingAttachment = attachmentPreparationCount > 0
        if let errorMessage {
            loadedState.errorMessage = errorMessage
        }
        state = .loaded(loadedState)
        if errorMessage != nil {
            scheduleErrorDismiss()
        }
    }

    func isCurrentAttachmentContext(_ contextId: UUID) -> Bool {
        guard case .loaded(let loadedState) = state else { return false }
        return (loadedState.conversation?.id ?? loadedState.pendingSessionId) == contextId
    }
}
