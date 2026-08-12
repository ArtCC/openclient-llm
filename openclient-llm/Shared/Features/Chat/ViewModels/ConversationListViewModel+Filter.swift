//
//  ConversationListViewModel+Filter.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ConversationListViewModel {
    func applySearchFilter(_ loadedState: inout LoadedState) {
        var base = loadedState.conversations

        if let tag = loadedState.activeTagFilter,
           loadedState.conversations.contains(where: { $0.tags.contains(where: { $0.name == tag }) }) {
            base = base.filter { $0.tags.contains(where: { $0.name == tag }) }
        } else {
            loadedState.activeTagFilter = nil
        }

        let query = loadedState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            loadedState.filteredConversations = base
            return
        }

        loadedState.filteredConversations = base.filter { conversation in
            conversation.title.lowercased().contains(query)
                || conversation.messages.contains { $0.content.lowercased().contains(query) }
        }
    }
}
