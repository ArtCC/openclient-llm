//
//  CheckOnboardingUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol CheckOnboardingUseCaseProtocol: Sendable {
    func execute() -> Bool
}

struct CheckOnboardingUseCase: CheckOnboardingUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol = SettingsManager()) {
        self.settingsManager = settingsManager
    }

    // MARK: - Execute

    func execute() -> Bool {
        settingsManager.getIsOnboardingCompleted()
    }
}
