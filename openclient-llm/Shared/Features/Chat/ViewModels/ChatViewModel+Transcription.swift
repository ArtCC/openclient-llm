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
        guard let transcriptionModelId = loadedState.transcriptionModelId else {
            LogManager.warning("transcribeAudio: no audioTranscription model available")
            loadedState.errorMessage = String(
                localized: "No speech-to-text model available. Configure a Whisper model in LiteLLM."
            )
            state = .loaded(loadedState)
            scheduleErrorDismiss()
            return
        }
        let durationStr = String(format: "%.1f", duration)
        LogManager.info(
            "transcribeAudio model=\(transcriptionModelId) data=\(data.count) bytes duration=\(durationStr)s"
        )
        loadedState.isTranscribing = true
        state = .loaded(loadedState)
        Task { await performTranscription(data: data, duration: duration, modelId: transcriptionModelId) }
    }

    func performTranscription(data: Data, duration: TimeInterval, modelId: String) async {
        do {
            LogManager.debug("performTranscription model=\(modelId)")
            let text = try await transcribeAudioUseCase.execute(
                audioData: data,
                model: modelId,
                language: nil,
                fileName: "recording.m4a"
            )
            guard case .loaded(var currentState) = state else { return }
            currentState.inputText = text
            currentState.isTranscribing = false
            state = .loaded(currentState)
            HapticsManager.success()
            LogManager.success("performTranscription done chars=\(text.count)")
        } catch {
            LogManager.error("performTranscription failed: \(error)")
            guard case .loaded(var currentState) = state else { return }
            currentState.isTranscribing = false
            currentState.errorMessage = error.localizedDescription
            state = .loaded(currentState)
            scheduleErrorDismiss()
        }
    }
}
