//
//  ResolveAudioModelIdsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - AudioModelIds

struct AudioModelIds: Sendable, Equatable {
    let ttsModelId: String?
    let transcriptionModelId: String
}

// MARK: - ResolveAudioModelIdsUseCase

protocol ResolveAudioModelIdsUseCaseProtocol: Sendable {
    func execute(from models: [LLMModel]) -> AudioModelIds
}

struct ResolveAudioModelIdsUseCase: ResolveAudioModelIdsUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol = SettingsManager()) {
        self.settingsManager = settingsManager
    }

    // MARK: - Execute

    func execute(from models: [LLMModel]) -> AudioModelIds {
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

        return AudioModelIds(ttsModelId: ttsModelId, transcriptionModelId: transcriptionModelId)
    }
}
