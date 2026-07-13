//
//  ChatViewModel+Helpers.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Internal helpers

extension ChatViewModel {
    func isActiveStream(_ assistantMessageId: UUID) -> Bool {
        activeAssistantMessageId == assistantMessageId
    }

    func completeActiveStream(_ assistantMessageId: UUID) {
        guard isActiveStream(assistantMessageId) else { return }
        activeAssistantMessageId = nil
        streamTask = nil
    }

    func buildEffectiveSystemPrompt(
        profileContext: String,
        memoryContext: String,
        conversationSystemPrompt: String
    ) -> String {
        let profile = profileContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = memoryContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversation = conversationSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []

        parts.append("""
        Respond in plain, natural language. \
        Never output raw JSON, XML, or other structured data formats in your responses \
        unless the user explicitly asks for it \
        (e.g. "give me a JSON", "format as JSON", "return structured data").
        """)

        if !profile.isEmpty {
            parts.append("""
            The following is background information about the user. \
            Use it only to personalize your responses when relevant — \
            do not mention it proactively or make it the topic of conversation.
            \(profile)
            """)
        }

        if !memory.isEmpty {
            parts.append("""
            The following are facts you know about the user from previous conversations. \
            Use them only when directly relevant to what the user is asking — \
            never bring them up unprompted.
            \(memory)
            """)
        }

        if !conversation.isEmpty {
            parts.append(conversation)
        }

        return parts.joined(separator: "\n\n")
    }

    func persistConversation() {
        guard !isPrivateChat else { return }
        guard case .loaded(var loadedState) = state,
              var conversation = loadedState.conversation else { return }

        conversation.messages = loadedState.messages
        conversation.systemPrompt = loadedState.systemPrompt
        conversation.modelParameters = loadedState.modelParameters
        conversation.updatedAt = Date()
        if let model = loadedState.selectedModel {
            conversation.modelId = model.id
        }
        loadedState.conversation = conversation
        state = .loaded(loadedState)

        do {
            try saveConversationUseCase.execute(conversation)
            NotificationCenter.default.post(name: .conversationDidUpdate, object: nil)
            onConversationUpdated?()
        } catch {
            LogManager.error("persistConversation failed: \(error)")
            // Silently fail — persistence is best-effort
        }
    }

    func generatedImageAttachment(
        data: Data,
        state: LoadedState
    ) -> ChatMessage.Attachment? {
        if isPrivateChat {
            return ChatMessage.Attachment(
                type: .image,
                fileName: String(localized: "Generated Image"),
                mimeType: "image/png",
                fileRelativePath: "",
                transientData: data
            )
        }
        let attachmentID = UUID()
        let placeholder = ChatMessage.Attachment(
            id: attachmentID,
            type: .image,
            fileName: String(localized: "Generated Image"),
            mimeType: "image/png",
            fileRelativePath: ""
        )
        guard let relativePath = try? attachmentRepository.save(
            data: data,
            for: placeholder,
            conversationId: state.conversation?.id ?? state.pendingSessionId
        ) else {
            LogManager.error("generatedImageAttachment: failed to save image")
            return nil
        }
        return ChatMessage.Attachment(
            id: attachmentID,
            type: .image,
            fileName: String(localized: "Generated Image"),
            mimeType: "image/png",
            fileRelativePath: relativePath
        )
    }

    func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            currentState.errorMessage = nil
            state = .loaded(currentState)
        }
    }
}
