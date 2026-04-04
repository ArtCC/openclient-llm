//
//  DeletePromptTemplateUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol DeletePromptTemplateUseCaseProtocol: Sendable {
    func execute(_ templateId: UUID) throws
}

struct DeletePromptTemplateUseCase: DeletePromptTemplateUseCaseProtocol {
    // MARK: - Properties

    private let repository: PromptTemplateRepositoryProtocol

    // MARK: - Init

    init(repository: PromptTemplateRepositoryProtocol = PromptTemplateRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute(_ templateId: UUID) throws {
        try repository.delete(templateId)
    }
}
