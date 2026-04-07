//
//  GetSelectedModelUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 07/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol GetSelectedModelUseCaseProtocol: Sendable {
    func execute() -> String
}

struct GetSelectedModelUseCase: GetSelectedModelUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol = SettingsManager()) {
        self.settingsManager = settingsManager
    }

    // MARK: - Execute

    func execute() -> String {
        settingsManager.getSelectedModelId() ?? ""
    }
}
