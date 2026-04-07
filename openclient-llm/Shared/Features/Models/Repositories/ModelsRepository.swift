//
//  ModelsRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ModelsRepositoryProtocol: Sendable {
    func fetchModels() async throws -> [LLMModel]
    func fetchModelInfo() async throws -> [LLMModel]
    func fetchOllamaModelDetails(for modelId: String, rootURL: String) async -> OllamaShowResponse?
}

struct ModelsRepository: ModelsRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Public

    func fetchModels() async throws -> [LLMModel] {
        LogManager.info("fetchModels")
        let response: ModelsResponse = try await apiClient.request(
            endpoint: "models",
            method: .get,
            body: nil
        )

        let models = response.data
            .map { LLMModel(id: $0.id, ownedBy: $0.ownedBy ?? "") }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
        LogManager.success("fetchModels returned \(models.count) models")
        return models
    }

    func fetchModelInfo() async throws -> [LLMModel] {
        LogManager.info("fetchModelInfo")
        let response: ModelInfoResponse = try await apiClient.request(
            endpoint: "model/info",
            method: .get,
            body: nil
        )

        let result = response.data.map { info in
            var capabilities: [LLMModel.Capability] = []

            if info.modelInfo?.supportsVision == true {
                capabilities.append(.vision)
            }
            if info.modelInfo?.supportsFunctionCalling == true {
                capabilities.append(.functionCalling)
            }
            if info.modelInfo?.supportsParallelFunctionCalling == true {
                capabilities.append(.parallelFunctionCalling)
            }
            if info.modelInfo?.supportsResponseSchema == true {
                capabilities.append(.jsonSchema)
            }

            let provider = LLMModel.Provider.from(info.modelInfo?.litellmProvider)
            let mode = LLMModel.Mode(rawString: info.modelInfo?.mode)
            let providerName = LLMModel.Provider.displayName(from: info.modelInfo?.litellmProvider)
            return LLMModel(
                id: info.modelName,
                capabilities: capabilities,
                provider: provider,
                mode: mode,
                providerName: providerName
            )
        }
        LogManager.success("fetchModelInfo returned \(result.count) models")
        return result
    }

    func fetchOllamaModelDetails(for modelId: String, rootURL: String) async -> OllamaShowResponse? {
        guard let url = URL(string: rootURL)?.appendingPathComponent("api/show") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        guard let body = try? JSONEncoder().encode(OllamaShowRequest(model: modelId)) else { return nil }
        request.httpBody = body

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(OllamaShowResponse.self, from: data)
    }
}
