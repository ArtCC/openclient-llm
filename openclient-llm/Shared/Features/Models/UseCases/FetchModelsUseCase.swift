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
        try await repository.fetchModels()
    }
}
