//
//  ConversationListView+EmptyState.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

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
            newChatEmptyStateMenu
#if os(macOS)
            .buttonStyle(.borderedProminent)
#endif
        }
    }
}
