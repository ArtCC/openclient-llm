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

    // MARK: - Public

    func fetchModels() async throws -> [LLMModel] {
        try fetchModelsResult.get()
    }
}
