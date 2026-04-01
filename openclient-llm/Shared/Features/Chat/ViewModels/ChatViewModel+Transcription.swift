//
//  ChatViewModel+Transcription.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Audio Transcription

extension ChatViewModel {
    func transcribeAudio(data: Data, duration: TimeInterval) {
        guard case .loaded(var loadedState) = state else { return }
        guard let selectedModel = loadedState.selectedModel else { return }
        loadedState.isTranscribing = true
        state = .loaded(loadedState)
        Task { await performTranscription(data: data, duration: duration, model: selectedModel) }
    }

    func performTranscription(data: Data, duration: TimeInterval, model: LLMModel) async {
        do {
            let text = try await transcribeAudioUseCase.execute(
                audioData: data,
                model: model.id,
                language: nil,
                fileName: "recording.m4a"
            )
            guard case .loaded(var currentState) = state else { return }
            currentState.inputText = text
            currentState.isTranscribing = false
            state = .loaded(currentState)
        } catch {
            guard case .loaded(var currentState) = state else { return }
            currentState.isTranscribing = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
            scheduleErrorDismiss()
        }
    }
}
