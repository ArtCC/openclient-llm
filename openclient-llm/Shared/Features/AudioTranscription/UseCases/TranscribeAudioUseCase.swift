//
//  TranscribeAudioUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol TranscribeAudioUseCaseProtocol: Sendable {
    func execute(audioData: Data, model: String, language: String?, fileName: String) async throws -> String
}

struct TranscribeAudioUseCase: TranscribeAudioUseCaseProtocol {
    // MARK: - Properties

    private let repository: AudioTranscriptionRepositoryProtocol

    // MARK: - Init

    init(repository: AudioTranscriptionRepositoryProtocol = AudioTranscriptionRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(audioData: Data, model: String, language: String?, fileName: String) async throws -> String {
        try await repository.transcribe(audioData: audioData, model: model, language: language, fileName: fileName)
    }
}
