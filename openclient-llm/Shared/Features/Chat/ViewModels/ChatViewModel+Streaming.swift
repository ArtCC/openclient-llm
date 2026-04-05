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
        parameters: ModelParameters,
        searchResults: [LiteLLMSearchResult] = []
    ) async {
        let hasSearch = !searchResults.isEmpty
        LogManager.debug("performStreaming model=\(model) messages=\(messages.count) webSearch=\(hasSearch)")
        let profileContext = userProfileManager.getProfile().systemPromptContext
        let effectiveSystemPrompt = buildEffectiveSystemPrompt(
            profileContext: profileContext,
            conversationSystemPrompt: systemPrompt
        )

        var allMessages = messages
        if !effectiveSystemPrompt.isEmpty {
            let systemMessage = ChatMessage(role: .system, content: effectiveSystemPrompt)
            allMessages.insert(systemMessage, at: 0)
        }
        if !searchResults.isEmpty {
            let contextMessage = ChatMessage(
                role: .system,
                content: buildWebSearchContext(results: searchResults)
            )
            allMessages.insert(contextMessage, at: allMessages.endIndex - 1)
        }

        do {
            let stream = streamMessageUseCase.execute(messages: allMessages, model: model, parameters: parameters)
            for try await chunk in stream {
                guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
                applyStreamChunk(chunk, to: &currentState, assistantMessageId: assistantMessageId)
                state = .loaded(currentState)
            }

            guard case .loaded(var currentState) = state else { return }
            currentState.isStreaming = false
            if !searchResults.isEmpty,
               let index = currentState.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                currentState.messages[index].webSearchResults = searchResults
            }
            state = .loaded(currentState)
            LogManager.success("performStreaming completed model=\(model)")
            persistConversation()
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
                let attachment = ChatMessage.Attachment(
                    type: .image,
                    fileName: String(localized: "Generated Image"),
                    data: imageData
                )
                state.messages[index].attachments.append(attachment)
            }
        }
    }
}
