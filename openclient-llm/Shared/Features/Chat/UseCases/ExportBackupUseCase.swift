//
//  ExportBackupUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ExportBackupUseCaseProtocol: Sendable {
    func execute() throws -> Data
}

struct ExportBackupUseCase: ExportBackupUseCaseProtocol {
    // MARK: - Properties

    private let loadConversationsUseCase: LoadConversationsUseCaseProtocol
    private let exportConversationsUseCase: ExportConversationsUseCaseProtocol

    // MARK: - Init

    init(
        loadConversationsUseCase: LoadConversationsUseCaseProtocol = LoadConversationsUseCase(),
        exportConversationsUseCase: ExportConversationsUseCaseProtocol = ExportConversationsUseCase()
    ) {
        self.loadConversationsUseCase = loadConversationsUseCase
        self.exportConversationsUseCase = exportConversationsUseCase
    }

    // MARK: - Execute

    func execute() throws -> Data {
        try exportConversationsUseCase.execute(loadConversationsUseCase.execute())
    }
}
