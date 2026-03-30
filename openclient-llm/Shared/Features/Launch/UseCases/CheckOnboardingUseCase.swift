//
//  CheckOnboardingUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
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
        settingsManager.isOnboardingCompleted
    }
}
