//
//  MockGetChatPreferencesUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockGetChatPreferencesUseCase: GetChatPreferencesUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var selectedModelId: String?
    var showTokenUsage: Bool = true
    var isWebSearchEnabled: Bool = false
    var ttsVoice: String = ""

    // MARK: - GetChatPreferencesUseCaseProtocol

    func getSelectedModelId() -> String? {
        selectedModelId
    }

    func getShowTokenUsage() -> Bool {
        showTokenUsage
    }

    func getIsWebSearchEnabled() -> Bool {
        isWebSearchEnabled
    }

    func getSelectedTTSVoice(forModelId modelId: String) -> String {
        ttsVoice
    }
}
