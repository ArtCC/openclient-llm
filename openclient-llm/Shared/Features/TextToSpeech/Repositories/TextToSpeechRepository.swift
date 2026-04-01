//
//  TextToSpeechRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol TextToSpeechRepositoryProtocol: Sendable {
    func synthesize(text: String, model: String, voice: String) async throws -> Data
}

struct TextToSpeechRepository: TextToSpeechRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func synthesize(text: String, model: String, voice: String) async throws -> Data {
        LogManager.info("synthesize model=\(model) voice=\(voice) chars=\(text.count)")
        let request = TextToSpeechRequest(
            model: model,
            input: text,
            voice: voice
        )

        let data = try await apiClient.rawDataRequest(
            endpoint: "v1/audio/speech",
            body: request
        )
        LogManager.success("synthesize done audioData=\(data.count) bytes")
        return data
    }
}
