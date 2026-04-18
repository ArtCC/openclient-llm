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
    func buildEffectiveSystemPrompt(
        profileContext: String,
        memoryContext: String,
        conversationSystemPrompt: String
    ) -> String {
        let profile = profileContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = memoryContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversation = conversationSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []

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
        guard case .loaded(let loadedState) = state,
              var conversation = loadedState.conversation else { return }

        conversation.messages = loadedState.messages
        conversation.systemPrompt = loadedState.systemPrompt
        conversation.modelParameters = loadedState.modelParameters
        conversation.updatedAt = Date()
        if let model = loadedState.selectedModel {
            conversation.modelId = model.id
        }

        do {
            try saveConversationUseCase.execute(conversation)
            NotificationCenter.default.post(name: .conversationDidUpdate, object: nil)
            onConversationUpdated?()
        } catch {
            LogManager.error("persistConversation failed: \(error)")
            // Silently fail — persistence is best-effort
        }
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
