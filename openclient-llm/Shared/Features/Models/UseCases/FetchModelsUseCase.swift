//
//  FetchModelsUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol FetchModelsUseCaseProtocol: Sendable {
    func execute() async throws -> [LLMModel]
}

struct FetchModelsUseCase: FetchModelsUseCaseProtocol {
    // MARK: - Properties

    private let repository: ModelsRepositoryProtocol

    // MARK: - Init

    init(repository: ModelsRepositoryProtocol = ModelsRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute() async throws -> [LLMModel] {
        var models = try await repository.fetchModels()

        if let modelInfoList = try? await repository.fetchModelInfo() {
            let capabilitiesByName = Dictionary(
                modelInfoList.map { ($0.id, $0.capabilities) },
                uniquingKeysWith: { _, last in last }
            )

            models = models.map { model in
                var updated = model
                if let capabilities = capabilitiesByName[model.id] {
                    updated.capabilities = capabilities
                }
                return updated
            }
        }

        return models
    }
}
