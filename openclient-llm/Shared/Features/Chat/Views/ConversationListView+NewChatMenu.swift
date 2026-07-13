//
//  ConversationListView+NewChatMenu.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

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
    }

    var newChatEmptyStateMenu: some View {
        Menu {
            newChatActions
        } label: {
            Text(String(localized: "New Chat"))
        }
        .menuOrder(.fixed)
    }

    @ViewBuilder
    var newChatActions: some View {
        Button {
            viewModel.send(.newConversationTapped)
        } label: {
            Label(String(localized: "New Chat"), systemImage: "square.and.pencil")
        }
        .keyboardShortcut("n", modifiers: .command)

        Button {
            isShowingEphemeralChat = true
        } label: {
            Label(String(localized: "New Private Chat"), systemImage: "lock.fill")
        }
    }
}
