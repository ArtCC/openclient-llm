//
//  ImageGenerationRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ImageGenerationRepositoryProtocol: Sendable {
    func generateImage(
        prompt: String,
        model: String,
        size: String,
        mode: LLMModel.Mode
    ) async throws -> GeneratedImage}

struct ImageGenerationRepository: ImageGenerationRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func generateImage(
        prompt: String,
        model: String,
        size: String,
        mode: LLMModel.Mode
    ) async throws -> GeneratedImage {
        switch mode {
        case .imageGeneration:
            try await generateViaImagesEndpoint(prompt: prompt, model: model, size: size)
        default:
            try await generateViaChatCompletions(prompt: prompt, model: model)
        }
    }
}

// MARK: - Private

private extension ImageGenerationRepository {
    func generateViaImagesEndpoint(prompt: String, model: String, size: String) async throws -> GeneratedImage {
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

    func generateViaChatCompletions(prompt: String, model: String) async throws -> GeneratedImage {
        let request = ChatCompletionRequest(
            model: model,
            messages: [ChatCompletionMessage(role: "user", content: .text(prompt))],
            stream: false,
            temperature: nil,
            maxTokens: nil,
            topP: nil,
            streamOptions: nil,
            modalities: ["image", "text"]
        )

        let response: ChatCompletionResponse = try await apiClient.request(
            endpoint: "chat/completions",
            method: .post,
            body: request
        )

        guard let content = response.choices.first?.message.content else {
            throw APIError.invalidResponse
        }

        let data = try extractImageData(from: content)

        return GeneratedImage(
            prompt: prompt,
            revisedPrompt: nil,
            imageData: data,
            modelId: model
        )
    }

    func extractImageData(from content: String) throws -> Data {
        let dataURIPrefix = "data:image/"

        guard let dataURIRange = content.range(of: dataURIPrefix) else {
            throw APIError.invalidResponse
        }

        let afterPrefix = content[dataURIRange.lowerBound...]
        guard let commaIndex = afterPrefix.firstIndex(of: ",") else {
            throw APIError.invalidResponse
        }

        let base64String = String(afterPrefix[afterPrefix.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = Data(base64Encoded: base64String) else {
            throw APIError.invalidResponse
        }

        return data
    }
}
