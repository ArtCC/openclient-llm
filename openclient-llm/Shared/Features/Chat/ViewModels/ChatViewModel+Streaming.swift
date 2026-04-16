//
//  ChatViewModel+Streaming.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Streaming helpers

extension ChatViewModel {
    func performStreaming(
        messages: [ChatMessage],
        model: String,
        assistantMessageId: UUID,
        systemPrompt: String,
        parameters: ModelParameters
    ) async {
        LogManager.debug("performStreaming model=\(model) messages=\(messages.count)")
        let allMessages = buildStreamMessages(messages, systemPrompt: systemPrompt)

        do {
            let stream = streamMessageUseCase.execute(
                messages: allMessages,
                model: model,
                parameters: parameters
            )
            for try await chunk in stream {
                guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
                applyStreamChunk(chunk, to: &currentState, assistantMessageId: assistantMessageId)
                state = .loaded(currentState)
            }

            guard case .loaded(var currentState) = state else { return }
            currentState.isStreaming = false
            state = .loaded(currentState)
            LogManager.success("performStreaming completed model=\(model)")
            persistConversation()
            streamingBackgroundUseCase.end()
            await notifyStreamingCompletedUseCase.execute()
        } catch {
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            LogManager.error("performStreaming error model=\(model): \(error)")
            if let index = currentState.messages.firstIndex(where: { $0.id == assistantMessageId }),
               currentState.messages[index].content.isEmpty {
                currentState.messages.remove(at: index)
            }
            currentState.isStreaming = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
            scheduleErrorDismiss()
            persistConversation()
            streamingBackgroundUseCase.end()
        }
    }

    func applyStreamChunk(_ chunk: StreamChunk, to state: inout LoadedState, assistantMessageId: UUID) {
        switch chunk {
        case .token(let token):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].content += token
            }
        case .reasoning(let text):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].reasoningContent = (state.messages[index].reasoningContent ?? "") + text
            }
        case .usage(let usage):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                state.messages[index].tokenUsage = usage
            }
        case .image(let imageData):
            if let index = state.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                let folderId = state.conversation?.id ?? state.pendingSessionId
                let attachmentId = UUID()
                let placeholder = ChatMessage.Attachment(
                    id: attachmentId,
                    type: .image,
                    fileName: String(localized: "Generated Image"),
                    mimeType: "image/png",
                    fileRelativePath: ""
                )
                if let relativePath = try? attachmentRepository.save(
                    data: imageData,
                    for: placeholder,
                    conversationId: folderId
                ) {
                    let attachment = ChatMessage.Attachment(
                        id: attachmentId,
                        type: .image,
                        fileName: String(localized: "Generated Image"),
                        mimeType: "image/png",
                        fileRelativePath: relativePath
                    )
                    state.messages[index].attachments.append(attachment)
                } else {
                    LogManager.error("applyStreamChunk: failed to save generated image")
                }
            }
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func buildStreamMessages(
        _ messages: [ChatMessage],
        systemPrompt: String
    ) -> [ChatMessage] {
        let profileContext = getUserProfileContextUseCase.execute()
        let memoryContext = getMemoryContextUseCase.execute()
        let effectiveSystemPrompt = buildEffectiveSystemPrompt(
            profileContext: profileContext,
            memoryContext: memoryContext,
            conversationSystemPrompt: systemPrompt
        )
        var result = messages
        if !effectiveSystemPrompt.isEmpty {
            result.insert(ChatMessage(role: .system, content: effectiveSystemPrompt), at: 0)
        }
        return result
    }
}
