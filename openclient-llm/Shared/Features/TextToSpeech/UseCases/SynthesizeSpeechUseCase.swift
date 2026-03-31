//
//  SynthesizeSpeechUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SynthesizeSpeechUseCaseProtocol: Sendable {
    func execute(text: String, model: String, voice: String) async throws -> Data
}

struct SynthesizeSpeechUseCase: SynthesizeSpeechUseCaseProtocol {
    // MARK: - Properties

    private let repository: TextToSpeechRepositoryProtocol

    // MARK: - Init

    init(repository: TextToSpeechRepositoryProtocol = TextToSpeechRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(text: String, model: String, voice: String) async throws -> Data {
        try await repository.synthesize(text: text, model: model, voice: voice)
    }
}
