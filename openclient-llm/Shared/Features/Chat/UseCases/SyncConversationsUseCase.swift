//
//  SyncConversationsUseCase.swift
//  openclient-llm
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol SyncConversationsUseCaseProtocol: Sendable {
    @discardableResult
    func execute() async -> ConversationSyncResult
    func cancel() async
}

struct SyncConversationsUseCase: SyncConversationsUseCaseProtocol {
    // MARK: - Properties

    private let repository: ConversationRepositoryProtocol

    // MARK: - Init

    init(repository: ConversationRepositoryProtocol = ConversationRepository()) {
        self.repository = repository
    }

    // MARK: - Execute

    @discardableResult
    func execute() async -> ConversationSyncResult {
        await repository.synchronize()
    }

    func cancel() async {
        await repository.cancelSynchronization()
    }
}
