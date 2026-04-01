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
        let shortPrompt = String(prompt.prefix(80))
        LogManager.info("generateImage model=\(model) size=\(size) mode=\(mode) prompt=\"\(shortPrompt)\"")
        switch mode {
        case .imageGeneration:
            return try await generateViaImagesEndpoint(prompt: prompt, model: model, size: size)
        default:
            return try await generateViaChatCompletions(prompt: prompt, model: model)
        }
    }
}

// MARK: - Private

private extension ImageGenerationRepository {
    func generateViaImagesEndpoint(prompt: String, model: String, size: String) async throws -> GeneratedImage {
        LogManager.debug("generateViaImagesEndpoint model=\(model)")
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
            LogManager.error("generateViaImagesEndpoint: response.data is empty")
            throw APIError.invalidResponse
        }

        let data: Data
        if let b64Json = imageData.b64Json, let decoded = Data(base64Encoded: b64Json) {
            LogManager.debug("generateViaImagesEndpoint: decoded b64_json \(decoded.count) bytes")
            data = decoded
        } else if let urlString = imageData.url, let url = URL(string: urlString) {
            LogManager.debug("generateViaImagesEndpoint: downloading from url=\(urlString.prefix(100))")
            data = try await URLSession.shared.data(from: url).0
            LogManager.debug("generateViaImagesEndpoint: downloaded \(data.count) bytes")
        } else {
            LogManager.error("generateViaImagesEndpoint: no b64Json and no url in response")
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
        LogManager.debug("generateViaChatCompletions model=\(model)")
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
            LogManager.error("generateViaChatCompletions: no content in response choices")
            throw APIError.invalidResponse
        }
        let preview = String(content.prefix(120))
        LogManager.debug("generateViaChatCompletions: response content length=\(content.count) preview=\(preview)")

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
            LogManager.error(
                "extractImageData: data URI prefix not found in content. Preview: \(String(content.prefix(200)))"
            )
            throw APIError.invalidResponse
        }

        let afterPrefix = content[dataURIRange.lowerBound...]
        guard let commaIndex = afterPrefix.firstIndex(of: ",") else {
            LogManager.error("extractImageData: comma separator not found after data URI prefix")
            throw APIError.invalidResponse
        }

        let base64String = String(afterPrefix[afterPrefix.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = Data(base64Encoded: base64String) else {
            LogManager.error("extractImageData: Base64 decoding failed (length=\(base64String.count))")
            throw APIError.invalidResponse
        }
        LogManager.debug("extractImageData: decoded \(data.count) bytes")
        return data
    }
}
