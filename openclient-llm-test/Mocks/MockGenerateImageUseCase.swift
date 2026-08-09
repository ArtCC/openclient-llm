//
//  MockGenerateImageUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockGenerateImageUseCase: GenerateImageUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<GeneratedImage, Error> = .failure(APIError.invalidResponse)
    var prompts: [String] = []
    var models: [String] = []

    // MARK: - Execute

    func execute(prompt: String, model: String) async throws -> GeneratedImage {
        prompts.append(prompt)
        models.append(model)
        return try result.get()
    }
}
