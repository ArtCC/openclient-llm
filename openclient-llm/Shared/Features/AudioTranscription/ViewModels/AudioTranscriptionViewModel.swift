//
//  AudioTranscriptionViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class AudioTranscriptionViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case modelSelected(String)
        case languageChanged(String)
        case audioRecorded(Data, TimeInterval)
        case audioFileSelected(Data, String)
        case transcribeTapped
        case clearTapped
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var selectedModel: String = ""
        var language: String = ""
        var availableModels: [LLMModel] = []
        var audioData: Data?
        var audioFileName: String?
        var audioDuration: TimeInterval = 0
        var transcriptions: [Transcription] = []
        var isTranscribing: Bool = false
        var errorMessage: String?
    }

    private(set) var state: State

    private let transcribeAudioUseCase: TranscribeAudioUseCaseProtocol
    private let fetchModelsUseCase: FetchModelsUseCaseProtocol

    // MARK: - Init

    init(
        state: State = .loading,
        transcribeAudioUseCase: TranscribeAudioUseCaseProtocol = TranscribeAudioUseCase(),
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase()
    ) {
        self.state = state
        self.transcribeAudioUseCase = transcribeAudioUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadModels()
        case .modelSelected(let model):
            selectModel(model)
        case .languageChanged(let language):
            updateLanguage(language)
        case .audioRecorded(let data, let duration):
            setRecordedAudio(data, duration: duration)
        case .audioFileSelected(let data, let fileName):
            setAudioFile(data, fileName: fileName)
        case .transcribeTapped:
            transcribe()
        case .clearTapped:
            clearAudio()
        }
    }
}

// MARK: - Private

private extension AudioTranscriptionViewModel {
    func loadModels() {
        state = .loading

        Task {
            do {
                let models = try await fetchModelsUseCase.execute()
                let defaultModel = models.first?.id ?? ""
                state = .loaded(LoadedState(
                    selectedModel: defaultModel,
                    availableModels: models
                ))
            } catch {
                state = .loaded(LoadedState(
                    errorMessage: error.localizedDescription
                ))
            }
        }
    }

    func selectModel(_ model: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.selectedModel = model
        state = .loaded(loadedState)
    }

    func updateLanguage(_ language: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.language = language
        state = .loaded(loadedState)
    }

    func setRecordedAudio(_ data: Data, duration: TimeInterval) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.audioData = data
        loadedState.audioFileName = "recording.m4a"
        loadedState.audioDuration = duration
        state = .loaded(loadedState)
    }

    func setAudioFile(_ data: Data, fileName: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.audioData = data
        loadedState.audioFileName = fileName
        loadedState.audioDuration = 0
        state = .loaded(loadedState)
    }

    func clearAudio() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.audioData = nil
        loadedState.audioFileName = nil
        loadedState.audioDuration = 0
        state = .loaded(loadedState)
    }

    func transcribe() {
        guard case .loaded(var loadedState) = state else { return }
        guard let audioData = loadedState.audioData,
              let fileName = loadedState.audioFileName,
              !loadedState.selectedModel.isEmpty,
              !loadedState.isTranscribing else { return }

        loadedState.isTranscribing = true
        loadedState.errorMessage = nil
        state = .loaded(loadedState)

        let model = loadedState.selectedModel
        let language = loadedState.language.isEmpty ? nil : loadedState.language
        let duration = loadedState.audioDuration

        Task {
            do {
                let text = try await transcribeAudioUseCase.execute(
                    audioData: audioData,
                    model: model,
                    language: language,
                    fileName: fileName
                )

                guard case .loaded(var currentState) = state else { return }
                let transcription = Transcription(
                    text: text,
                    modelId: model,
                    duration: duration
                )
                currentState.transcriptions.insert(transcription, at: 0)
                currentState.isTranscribing = false
                currentState.audioData = nil
                currentState.audioFileName = nil
                currentState.audioDuration = 0
                state = .loaded(currentState)
            } catch {
                guard case .loaded(var currentState) = state else { return }
                currentState.isTranscribing = false
                currentState.errorMessage = error.localizedDescription
                state = .loaded(currentState)
            }
        }
    }
}
