//
//  ResetAppDataUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ResetAppDataUseCaseProtocol: Sendable {
    func execute()
}

struct ResetAppDataUseCase: ResetAppDataUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol
    private let conversationRepository: ConversationRepositoryProtocol
    private let userProfileManager: UserProfileManagerProtocol
    private let memoryManager: MemoryManagerProtocol

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        conversationRepository: ConversationRepositoryProtocol = ConversationRepository(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        memoryManager: MemoryManagerProtocol = MemoryManager()
    ) {
        self.settingsManager = settingsManager
        self.conversationRepository = conversationRepository
        self.userProfileManager = userProfileManager
        self.memoryManager = memoryManager
    }

    // MARK: - Execute

    func execute() {
        // Disable cloud sync first so subsequent deletes do NOT touch iCloud.
        settingsManager.deleteAll()
        try? conversationRepository.deleteAll()
        userProfileManager.deleteLocalProfile()
        memoryManager.deleteAll()
    }
}
