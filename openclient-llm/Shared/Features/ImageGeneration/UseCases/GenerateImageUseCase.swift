//
//  GenerateImageUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol GenerateImageUseCaseProtocol: Sendable {
    func execute(prompt: String, model: String, size: String) async throws -> GeneratedImage
}

struct GenerateImageUseCase: GenerateImageUseCaseProtocol {
    // MARK: - Properties

    private let repository: ImageGenerationRepositoryProtocol

    // MARK: - Init

    init(repository: ImageGenerationRepositoryProtocol = ImageGenerationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(prompt: String, model: String, size: String) async throws -> GeneratedImage {
        try await repository.generateImage(prompt: prompt, model: model, size: size)
    }
}
