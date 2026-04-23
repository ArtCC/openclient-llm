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
        case shareItemReceived
        case shareItemConsumed
        case urlSchemeActionReceived
        case urlSchemeTextConsumed
    }

    private(set) var pendingConversation: Conversation?
    private(set) var pendingShareItem: ShareExtensionItem?
    private(set) var pendingURLSchemeText: String?

    var pendingShortcutAction: ShortcutAction? {
        shortcutManager.pendingAction
    }

    var hasPendingShare: Bool {
        shareManager.hasPendingShare
    }

    var pendingURLSchemeAction: URLSchemeAction? {
        urlSchemeManager.pendingAction
    }

    private let getSelectedModelUseCase: GetSelectedModelUseCaseProtocol
    private let loadConversationsUseCase: LoadConversationsUseCaseProtocol
    private let shortcutManager: ShortcutManager
    private let shareManager: ShareManager
    private let urlSchemeManager: URLSchemeManager
    private let checkNotificationPermissionUseCase: NotificationStatusCheckProtocol
    private let notificationPermissionUseCase: NotificationPermissionUseCaseProtocol

    // MARK: - Init

    init(
        getSelectedModelUseCase: GetSelectedModelUseCaseProtocol = GetSelectedModelUseCase(),
        loadConversationsUseCase: LoadConversationsUseCaseProtocol = LoadConversationsUseCase(),
        shortcutManager: ShortcutManager = .shared,
        shareManager: ShareManager = .shared,
        urlSchemeManager: URLSchemeManager = .shared,
        checkNotificationPermissionUseCase: NotificationStatusCheckProtocol = CheckNotificationPermissionUseCase(),
        notificationPermissionUseCase: NotificationPermissionUseCaseProtocol = NotificationPermissionUseCase()
    ) {
        self.getSelectedModelUseCase = getSelectedModelUseCase
        self.loadConversationsUseCase = loadConversationsUseCase
        self.shortcutManager = shortcutManager
        self.shareManager = shareManager
        self.urlSchemeManager = urlSchemeManager
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
        case .shareItemReceived:
            resolveShareItem()
        case .shareItemConsumed:
            pendingShareItem = nil
        case .urlSchemeActionReceived:
            resolveURLSchemeAction()
        case .urlSchemeTextConsumed:
            pendingURLSchemeText = nil
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

    func resolveShareItem() {
        shareManager.hasPendingShare = false
        let modelId = getSelectedModelUseCase.execute()
        pendingShareItem = try? ShareExtensionStore.load()
        pendingConversation = Conversation(modelId: modelId)
    }

    func resolveURLSchemeAction() {
        guard let action = urlSchemeManager.pendingAction else { return }
        urlSchemeManager.pendingAction = nil
        let modelId = getSelectedModelUseCase.execute()
        switch action {
        case .newChat:
            pendingConversation = Conversation(modelId: modelId)
        case .search:
            shortcutManager.pendingAction = .search
        case .chat(let text, let url):
            let parts = [text, url].compactMap { $0 }.filter { !$0.isEmpty }
            pendingURLSchemeText = parts.isEmpty ? nil : parts.joined(separator: "\n")
            pendingConversation = Conversation(modelId: modelId)
        case .conversation(let id):
            resolveSpotlightConversation(id: id)
        }
    }
}
