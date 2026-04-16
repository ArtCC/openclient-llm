//
//  GetMemoryContextUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol GetMemoryContextUseCaseProtocol: Sendable {
    func execute() -> String
}

struct GetMemoryContextUseCase: GetMemoryContextUseCaseProtocol {
    // MARK: - Properties

    private let manager: MemoryManagerProtocol

    // MARK: - Init

    init(manager: MemoryManagerProtocol = MemoryManager()) {
        self.manager = manager
    }

    // MARK: - Execute

    func execute() -> String {
        let enabledItems = manager.getItems().filter { $0.isEnabled }
        guard !enabledItems.isEmpty else { return "" }

        let lines = enabledItems.map { "- \($0.content)" }.joined(separator: "\n")
        return "## Memory\n\(lines)"
    }
}
