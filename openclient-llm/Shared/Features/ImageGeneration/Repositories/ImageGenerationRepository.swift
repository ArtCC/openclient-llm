//
//  ImageGenerationRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ImageGenerationRepositoryProtocol: Sendable {
    func generateImage(prompt: String, model: String, size: String) async throws -> GeneratedImage
}

struct ImageGenerationRepository: ImageGenerationRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func generateImage(prompt: String, model: String, size: String) async throws -> GeneratedImage {
        let request = ImageGenerationRequest(
            model: model,
            prompt: prompt,
            numberOfImages: 1,
            size: size,
            responseFormat: "b64_json"
        )

        let response: ImageGenerationResponse = try await apiClient.request(
            endpoint: "v1/images/generations",
            method: .post,
            body: request
        )

        guard let imageData = response.data.first else {
            throw APIError.invalidResponse
        }

        guard let b64Json = imageData.b64Json,
              let data = Data(base64Encoded: b64Json) else {
            throw APIError.invalidResponse
        }

        return GeneratedImage(
            prompt: prompt,
            revisedPrompt: imageData.revisedPrompt,
            imageData: data,
            modelId: model
        )
    }
}
