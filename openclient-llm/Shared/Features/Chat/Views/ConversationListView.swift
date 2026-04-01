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
    @State private var searchText: String = ""

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
        .searchable(
            text: $searchText,
            prompt: String(localized: "Search conversations...")
        )
        .onChange(of: searchText) { _, newValue in
            viewModel.send(.searchChanged(newValue))
        }
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
            } else if loadedState.filteredConversations.isEmpty {
                noSearchResults
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

    var noSearchResults: some View {
        ContentUnavailableView.search(text: searchText)
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
            ForEach(loadedState.groupedConversations) { section in
                Section {
                    ForEach(section.conversations) { conversation in
                        conversationRow(conversation, loadedState: loadedState)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let conversation = section.conversations[index]
                            viewModel.send(.deleteConversation(conversation.id))
                        }
                    }
                } header: {
                    Text(section.period.localizedTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.refresh()
        }
    }

    func conversationRow(
        _ conversation: Conversation,
        loadedState: ConversationListViewModel.LoadedState
    ) -> some View {
        let isSelected = loadedState.selectedConversation?.id == conversation.id

        return Button {
            viewModel.send(.conversationTapped(conversation))
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .glassEffect(
                        isSelected ? .regular.tint(Color.accentColor) : .regular,
                        in: .circle
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(conversationTitle(conversation))
                            .font(.headline)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(formattedDate(conversation.updatedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let lastMessage = conversation.messages.last(where: { $0.role != .system }) {
                        Text(lastMessage.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    modelBadge(conversation.modelId)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    func modelBadge(_ modelId: String) -> some View {
        let name = modelId.split(separator: "/").last.map(String.init) ?? modelId
        return Text(name)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: .capsule)
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
