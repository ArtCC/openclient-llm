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
        let response: ModelsResponse = try await apiClient.request(
            endpoint: "models",
            method: .get,
            body: nil
        )

        return response.data
            .map { LLMModel(id: $0.id, ownedBy: $0.ownedBy ?? "") }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    func fetchModelInfo() async throws -> [LLMModel] {
        let response: ModelInfoResponse = try await apiClient.request(
            endpoint: "model/info",
            method: .get,
            body: nil
        )

        return response.data.map { info in
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
            return LLMModel(id: info.modelName, capabilities: capabilities, provider: provider)
        }
    }
}
