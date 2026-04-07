//
//  HomeViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 07/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class HomeViewModel {
    // MARK: - Properties

    enum Event {
        case newChatShortcutTriggered
        case spotlightConversationRequested(UUID)
        case pendingConversationConsumed
    }

    private(set) var pendingConversation: Conversation?

    private let getSelectedModelUseCase: GetSelectedModelUseCaseProtocol
    private let loadConversationsUseCase: LoadConversationsUseCaseProtocol

    // MARK: - Init

    init(
        getSelectedModelUseCase: GetSelectedModelUseCaseProtocol = GetSelectedModelUseCase(),
        loadConversationsUseCase: LoadConversationsUseCaseProtocol = LoadConversationsUseCase()
    ) {
        self.getSelectedModelUseCase = getSelectedModelUseCase
        self.loadConversationsUseCase = loadConversationsUseCase
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .newChatShortcutTriggered:
            let modelId = getSelectedModelUseCase.execute()
            pendingConversation = Conversation(modelId: modelId)
        case .spotlightConversationRequested(let id):
            resolveSpotlightConversation(id: id)
        case .pendingConversationConsumed:
            pendingConversation = nil
        }
    }
}

// MARK: - Private

private extension HomeViewModel {
    func resolveSpotlightConversation(id: UUID) {
        Task {
            guard let conversations = try? loadConversationsUseCase.execute(),
                  let conversation = conversations.first(where: { $0.id == id }) else { return }
            pendingConversation = conversation
        }
    }
}
