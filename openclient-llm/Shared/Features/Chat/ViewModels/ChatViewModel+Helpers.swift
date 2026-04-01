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
    func buildEffectiveSystemPrompt(profileContext: String, conversationSystemPrompt: String) -> String {
        let profile = profileContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversation = conversationSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (profile.isEmpty, conversation.isEmpty) {
        case (true, true): return ""
        case (false, true): return profile
        case (true, false): return conversation
        case (false, false): return "\(profile)\n\n\(conversation)"
        }
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
