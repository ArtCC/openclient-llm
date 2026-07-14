//
//  ConversationListView+Tips.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ConversationListView {
    // MARK: - Tips

    func updateMemoryTipEligibility(conversationCount: Int) {
        if conversationCount >= 3 {
            settingsManager.setHasEnoughConversationsForMemoryTip(true)
        }
    }

    func organizationTip(
        for conversation: Conversation,
        loadedState: ConversationListViewModel.LoadedState
    ) -> ConversationOrganizationTip? {
        guard loadedState.conversations.count >= 5,
              conversation.id == loadedState.filteredConversations.first?.id else {
            return nil
        }
        return AppTips.conversationOrganization
    }

    // MARK: - Formatting

    func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: .now).day, daysAgo < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}
