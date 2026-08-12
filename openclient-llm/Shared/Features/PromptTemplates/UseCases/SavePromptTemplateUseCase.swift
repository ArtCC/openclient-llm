//
//  SavePromptTemplateUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SavePromptTemplateUseCaseProtocol: Sendable {
    func execute(_ template: PromptTemplate) async throws
}

struct SavePromptTemplateUseCase: SavePromptTemplateUseCaseProtocol {
    // MARK: - Properties

    private let repository: PromptTemplateRepositoryProtocol

    // MARK: - Init

    init(repository: PromptTemplateRepositoryProtocol = PromptTemplateRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ template: PromptTemplate) async throws {
        try await repository.save(template)
    }
}
