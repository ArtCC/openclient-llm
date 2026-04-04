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

// MARK: - Audio model helpers

extension ChatViewModel {
    func resolveAudioModelIds(from models: [LLMModel]) -> (ttsModelId: String?, transcriptionModelId: String?) {
        let savedTTSModelId = settingsManager.getSelectedTTSModelId()
        let ttsModelId = models.first(where: { $0.id == savedTTSModelId && $0.mode == .audioSpeech })?.id
            ?? models.first(where: { $0.mode == .audioSpeech })?.id
        let savedSTTModelId = settingsManager.getSelectedSTTModelId()
        let transcriptionModelId: String
        if let savedId = savedSTTModelId, savedId != LLMModel.appleSpeechRecognition.id {
            transcriptionModelId = models.first(where: {
                $0.id == savedId && $0.mode == .audioTranscription
            })?.id ?? LLMModel.appleSpeechRecognition.id
        } else {
            transcriptionModelId = LLMModel.appleSpeechRecognition.id
        }
        return (ttsModelId, transcriptionModelId)
    }
}
