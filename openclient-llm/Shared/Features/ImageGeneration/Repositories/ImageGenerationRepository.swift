//
//  ImageGenerationRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ImageGenerationRepositoryProtocol: Sendable {
    func generateImage(prompt: String, model: String) async throws -> GeneratedImage
}

struct ImageGenerationRepository: ImageGenerationRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func generateImage(prompt: String, model: String) async throws -> GeneratedImage {
        let request = ImageGenerationRequest(
            model: model,
            prompt: prompt,
            numberOfImages: 1,
            size: "1024x1024",
            responseFormat: "b64_json"
        )
        let response: ImageGenerationResponse = try await apiClient.request(
            endpoint: "images/generations",
            method: .post,
            body: request,
            timeoutInterval: 600
        )
        guard let image = response.data.first else { throw APIError.invalidResponse }

        if let encoded = image.b64Json,
           let data = Data(base64Encoded: encoded),
           !data.isEmpty,
           data.count <= 25 * 1_024 * 1_024 {
            return GeneratedImage(data: data, mimeType: "image/png", revisedPrompt: image.revisedPrompt)
        }

        guard let urlString = image.url,
              let url = URL(string: urlString) else { throw APIError.invalidResponse }
        let downloaded = try await apiClient.downloadData(from: url)
        guard !downloaded.data.isEmpty,
              downloaded.mimeType.hasPrefix("image/") else { throw APIError.invalidResponse }
        return GeneratedImage(
            data: downloaded.data,
            mimeType: downloaded.mimeType,
            revisedPrompt: image.revisedPrompt
        )
    }
}
