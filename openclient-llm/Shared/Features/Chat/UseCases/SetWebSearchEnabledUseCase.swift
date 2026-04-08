//
//  SetWebSearchEnabledUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SetWebSearchEnabledUseCaseProtocol: Sendable {
    func execute(_ value: Bool)
}

struct SetWebSearchEnabledUseCase: SetWebSearchEnabledUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol = SettingsManager()) {
        self.settingsManager = settingsManager
    }

    // MARK: - Execute

    func execute(_ value: Bool) {
        settingsManager.setIsWebSearchEnabled(value)
    }
}
