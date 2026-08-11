//
//  ResetAppDataUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ResetAppDataUseCaseProtocol: Sendable {
    func execute() async throws
}

struct ResetAppDataUseCase: ResetAppDataUseCaseProtocol {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol
    private let conversationRepository: ConversationRepositoryProtocol
    private let userProfileManager: UserProfileManagerProtocol
    private let memoryManager: MemoryManagerProtocol
    private let categoryOperationGate: CloudCategoryOperationGate

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        conversationRepository: ConversationRepositoryProtocol = ConversationRepository(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        memoryManager: MemoryManagerProtocol = MemoryManager(),
        categoryOperationGate: CloudCategoryOperationGate = .shared
    ) {
        self.settingsManager = settingsManager
        self.conversationRepository = conversationRepository
        self.userProfileManager = userProfileManager
        self.memoryManager = memoryManager
        self.categoryOperationGate = categoryOperationGate
    }

    // MARK: - Execute

    func execute() async throws {
        try await categoryOperationGate.fence {
            // Disable cloud sync while profile cloud operations remain fenced.
            await settingsManager.deleteAll()
            try await conversationRepository.cancelSynchronizationAndDeleteAll()
            try await userProfileManager.deleteLocalProfile()
            try await memoryManager.deleteAll()
        }
    }
}
