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
    private let promptTemplateRepository: PromptTemplateRepositoryProtocol
    private let categoryOperationGate: CloudCategoryOperationGate
    private let mutationGate: CloudSynchronizationMutationGate

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        conversationRepository: ConversationRepositoryProtocol = ConversationRepository(),
        userProfileManager: UserProfileManagerProtocol = UserProfileManager(),
        memoryManager: MemoryManagerProtocol = MemoryManager(),
        promptTemplateRepository: PromptTemplateRepositoryProtocol = PromptTemplateRepository(),
        categoryOperationGate: CloudCategoryOperationGate = .shared,
        mutationGate: CloudSynchronizationMutationGate = .shared
    ) {
        self.settingsManager = settingsManager
        self.conversationRepository = conversationRepository
        self.userProfileManager = userProfileManager
        self.memoryManager = memoryManager
        self.promptTemplateRepository = promptTemplateRepository
        self.categoryOperationGate = categoryOperationGate
        self.mutationGate = mutationGate
    }

    // MARK: - Execute

    func execute() async throws {
        try await mutationGate.perform {
            try await self.categoryOperationGate.fence {
                try await self.conversationRepository.validateLocalReset()
                try await self.userProfileManager.validateLocalReset()
                try await self.memoryManager.validateLocalReset()
                try await self.promptTemplateRepository.validateLocalReset()

                try await self.conversationRepository.cancelSynchronizationAndDeleteAll()
                try await self.userProfileManager.deleteLocalProfile()
                try await self.memoryManager.deleteLocalData()
                try await self.promptTemplateRepository.deleteAllLocal()
                await self.settingsManager.deleteAll()
            }
        }
    }
}
