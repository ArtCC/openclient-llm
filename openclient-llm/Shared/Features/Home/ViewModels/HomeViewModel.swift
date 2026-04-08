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
        case viewAppeared
        case newChatShortcutTriggered
        case shortcutActionConsumed
        case spotlightConversationRequested(UUID)
        case pendingConversationConsumed
    }

    private(set) var pendingConversation: Conversation?

    var pendingShortcutAction: ShortcutAction? {
        shortcutManager.pendingAction
    }

    private let getSelectedModelUseCase: GetSelectedModelUseCaseProtocol
    private let loadConversationsUseCase: LoadConversationsUseCaseProtocol
    private let shortcutManager: ShortcutManager
    private let checkNotificationPermissionUseCase: NotificationStatusCheckProtocol
    private let notificationPermissionUseCase: NotificationPermissionUseCaseProtocol

    // MARK: - Init

    init(
        getSelectedModelUseCase: GetSelectedModelUseCaseProtocol = GetSelectedModelUseCase(),
        loadConversationsUseCase: LoadConversationsUseCaseProtocol = LoadConversationsUseCase(),
        shortcutManager: ShortcutManager = .shared,
        checkNotificationPermissionUseCase: NotificationStatusCheckProtocol = CheckNotificationPermissionUseCase(),
        notificationPermissionUseCase: NotificationPermissionUseCaseProtocol = NotificationPermissionUseCase()
    ) {
        self.getSelectedModelUseCase = getSelectedModelUseCase
        self.loadConversationsUseCase = loadConversationsUseCase
        self.shortcutManager = shortcutManager
        self.checkNotificationPermissionUseCase = checkNotificationPermissionUseCase
        self.notificationPermissionUseCase = notificationPermissionUseCase
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            checkNotificationPermissionIfNeeded()
        case .newChatShortcutTriggered:
            let modelId = getSelectedModelUseCase.execute()
            pendingConversation = Conversation(modelId: modelId)
        case .shortcutActionConsumed:
            shortcutManager.pendingAction = nil
        case .spotlightConversationRequested(let id):
            resolveSpotlightConversation(id: id)
        case .pendingConversationConsumed:
            pendingConversation = nil
        }
    }
}

// MARK: - Private

private extension HomeViewModel {
    func checkNotificationPermissionIfNeeded() {
        Task {
            let status = await checkNotificationPermissionUseCase.execute()
            guard status == .notDetermined else { return }
            await notificationPermissionUseCase.execute()
        }
    }

    func resolveSpotlightConversation(id: UUID) {
        Task {
            guard let conversations = try? loadConversationsUseCase.execute(),
                  let conversation = conversations.first(where: { $0.id == id }) else { return }
            pendingConversation = conversation
        }
    }
}
