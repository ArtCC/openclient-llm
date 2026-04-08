//
//  SaveSelectedModelUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SaveSelectedModelUseCaseProtocol: Sendable {
    func execute(modelId: String?)
}

struct SaveSelectedModelUseCase: SaveSelectedModelUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol = SettingsManager()) {
        self.settingsManager = settingsManager
    }

    // MARK: - Execute

    func execute(modelId: String?) {
        settingsManager.setSelectedModelId(modelId)
    }
}
