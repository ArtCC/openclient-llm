//
//  ConversationListView+EmptyState.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
import TipKit

extension ConversationListView {
    // MARK: - Empty State

    var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "No Conversations"),
                systemImage: "bubble.left.and.bubble.right"
            )
        } description: {
            Text(String(localized: "Start a new conversation to begin chatting"))
        } actions: {
            VStack(spacing: 15) {
                Button {
                    viewModel.send(.newConversationTapped)
                } label: {
                    Label(String(localized: "New Chat"), systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button {
                    AppTips.privateChat.invalidate(reason: .actionPerformed)
                    onPrivateChatSelected()
                } label: {
                    Label(String(localized: "New Private Chat"), systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            .padding(.top, 15)
            .padding(.horizontal)
        }
    }
}
