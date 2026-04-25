//
//  GetChatPreferencesUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol GetChatPreferencesUseCaseProtocol: Sendable {
    func getSelectedModelId() -> String?
    func getShowTokenUsage() -> Bool
    func getIsWebSearchEnabled() -> Bool
    func getWebSearchToolName() -> String
    func getSelectedTTSVoice(forModelId modelId: String) -> String
}

struct GetChatPreferencesUseCase: GetChatPreferencesUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol = SettingsManager()) {
        self.settingsManager = settingsManager
    }

    // MARK: - Execute

    func getSelectedModelId() -> String? {
        settingsManager.getSelectedModelId()
    }

    func getShowTokenUsage() -> Bool {
        settingsManager.getShowTokenUsage()
    }

    func getIsWebSearchEnabled() -> Bool {
        settingsManager.getIsWebSearchEnabled()
    }

    func getWebSearchToolName() -> String {
        settingsManager.getWebSearchToolName()
    }

    func getSelectedTTSVoice(forModelId modelId: String) -> String {
        settingsManager.getSelectedTTSVoice(forModelId: modelId)
    }
}
