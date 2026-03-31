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
        let request = TextToSpeechRequest(
            model: model,
            input: text,
            voice: voice
        )

        return try await apiClient.rawDataRequest(
            endpoint: "v1/audio/speech",
            body: request
        )
    }
}
