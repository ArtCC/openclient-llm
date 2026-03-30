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
}
