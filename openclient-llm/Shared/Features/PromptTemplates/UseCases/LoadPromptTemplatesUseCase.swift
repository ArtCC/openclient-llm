//
//  LoadPromptTemplatesUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol LoadPromptTemplatesUseCaseProtocol: Sendable {
    func execute() throws -> [PromptTemplate]
}

struct LoadPromptTemplatesUseCase: LoadPromptTemplatesUseCaseProtocol {
    // MARK: - Properties

    private let repository: PromptTemplateRepositoryProtocol

    // MARK: - Init

    init(repository: PromptTemplateRepositoryProtocol = PromptTemplateRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    func execute() throws -> [PromptTemplate] {
        try repository.loadAll()
    }
}
