//
//  MockModelsRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockModelsRepository: ModelsRepositoryProtocol, @unchecked Sendable {
    // MARK: - Properties

    var fetchModelsResult: Result<[LLMModel], Error> = .success([])
    var fetchModelInfoResult: Result<[LLMModel], Error> = .success([])
    var fetchOllamaModelDetailsResult: OllamaShowResponse?

    // MARK: - Public

    func fetchModels() async throws -> [LLMModel] {
        try fetchModelsResult.get()
    }

    func fetchModelInfo() async throws -> [LLMModel] {
        try fetchModelInfoResult.get()
    }

    func fetchOllamaModelDetails(for modelId: String, rootURL: String) async -> OllamaShowResponse? {
        fetchOllamaModelDetailsResult
    }
}
