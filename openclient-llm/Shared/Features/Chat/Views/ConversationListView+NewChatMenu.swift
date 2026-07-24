//
//  ConversationListView+NewChatMenu.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import TipKit

extension ConversationListView {
    // MARK: - New Chat Menu

    var newChatToolbarMenu: some View {
        Menu {
            newChatActions
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .help(String(localized: "New Chat"))
        .accessibilityLabel(String(localized: "New Chat"))
        .menuOrder(.fixed)
        .popoverTip(canShowPrivateChatTip ? AppTips.privateChat : nil)
    }

    var canShowPrivateChatTip: Bool {
        guard case .loaded(let loadedState) = viewModel.state else { return false }
        return !loadedState.conversations.isEmpty
    }

    @ViewBuilder
    var newChatActions: some View {
        Button {
            viewModel.send(.newConversationTapped)
        } label: {
            Label(String(localized: "New Chat"), systemImage: "square.and.pencil")
        }
        .keyboardShortcut("c", modifiers: .command)

        Button {
            AppTips.privateChat.invalidate(reason: .actionPerformed)
            onPrivateChatSelected()
        } label: {
            Label(String(localized: "New Private Chat"), systemImage: "lock.fill")
        }
        .keyboardShortcut("p", modifiers: .command)
    }
}
