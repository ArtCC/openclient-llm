//
//  AudioTranscriptionRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol AudioTranscriptionRepositoryProtocol: Sendable {
    func transcribe(audioData: Data, model: String, language: String?, fileName: String) async throws -> String
}

struct AudioTranscriptionRepository: AudioTranscriptionRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func transcribe(audioData: Data, model: String, language: String?, fileName: String) async throws -> String {
        var fields: [String: String] = ["model": model]
        if let language, !language.isEmpty {
            fields["language"] = language
        }

        let response: AudioTranscriptionResponse = try await apiClient.multipartRequest(
            endpoint: "v1/audio/transcriptions",
            fields: fields,
            fileField: "file",
            fileData: audioData,
            fileName: fileName,
            mimeType: "audio/m4a"
        )

        return response.text
    }
}
