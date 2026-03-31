//
//  ConversationListView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ConversationListView: View {
    // MARK: - Properties

    @State private var viewModel = ConversationListViewModel()

    let onConversationSelected: (Conversation?) -> Void

    // MARK: - View

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded(let loadedState):
                loadedView(loadedState)
            }
        }
        #if os(macOS)
        .focusedSceneValue(\.newChatAction) {
            viewModel.send(.newConversationTapped)
        }
        #endif
        .task {
            viewModel.onConversationSelected = onConversationSelected
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension ConversationListView {
    func loadedView(_ loadedState: ConversationListViewModel.LoadedState) -> some View {
        Group {
            if loadedState.conversations.isEmpty {
                emptyState
            } else {
                conversationList(loadedState)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.send(.newConversationTapped)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(String(localized: "New Chat"))
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "No Conversations"),
                systemImage: "bubble.left.and.bubble.right"
            )
        } description: {
            Text(String(localized: "Start a new conversation to begin chatting"))
        } actions: {
            Button(String(localized: "New Chat")) {
                viewModel.send(.newConversationTapped)
            }
#if os(macOS)
            .buttonStyle(.borderedProminent)
#endif
        }
    }

    func conversationList(_ loadedState: ConversationListViewModel.LoadedState) -> some View {
        List {
            ForEach(loadedState.conversations) { conversation in
                conversationRow(conversation, loadedState: loadedState)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let conversation = loadedState.conversations[index]
                    viewModel.send(.deleteConversation(conversation.id))
                }
            }
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    func conversationRow(
        _ conversation: Conversation,
        loadedState: ConversationListViewModel.LoadedState
    ) -> some View {
        Button {
            viewModel.send(.conversationTapped(conversation))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversationTitle(conversation))
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(conversation.modelId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(formattedDate(conversation.createdAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let lastMessage = conversation.messages.last(where: { $0.role != .system }) {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            loadedState.selectedConversation?.id == conversation.id
                ? Color.accentColor.opacity(0.1)
                : Color.clear
        )
    }

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

    func conversationTitle(_ conversation: Conversation) -> String {
        if !conversation.title.isEmpty {
            return conversation.title
        }
        if let firstUserMessage = conversation.messages.first(where: { $0.role == .user }) {
            let preview = firstUserMessage.content.prefix(50)
            return preview.count < firstUserMessage.content.count
                ? "\(preview)…"
                : String(preview)
        }
        return String(localized: "New Chat")
    }
}

#Preview {
    NavigationStack {
        ConversationListView { _ in }
            .navigationTitle(String(localized: "Chats"))
    }
}
