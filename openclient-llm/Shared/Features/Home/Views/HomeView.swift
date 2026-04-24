//
//  HomeView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    // MARK: - Properties

    @State private var viewModel = HomeViewModel()
    @State private var selectedConversation: Conversation?

#if os(macOS)
    @State private var sidebarDestination: SidebarDestination = .chats
#endif

#if os(iOS)
    @State private var selectedTab: AppTab = .chats
#endif

    // MARK: - View

    var body: some View {
        Group {
#if os(macOS)
            macOSLayout
#else
            iOSLayout
#endif
        }
        .onContinueUserActivity(SpotlightConstants.activityType) { activity in
            guard let idString = activity.userInfo?[SpotlightConstants.activityIdentifierKey] as? String,
                  let id = UUID(uuidString: idString) else { return }
            viewModel.send(.spotlightConversationRequested(id))
        }
        .task {
            viewModel.send(.viewAppeared)
        }
        .onChange(of: viewModel.pendingConversation) { _, conversation in
            guard let conversation else { return }
#if os(iOS)
            selectedTab = .chats
#elseif os(macOS)
            sidebarDestination = .chats
#endif
            selectedConversation = conversation
            viewModel.send(.pendingConversationConsumed)
        }
#if os(iOS)
        .task {
            guard let action = viewModel.pendingShortcutAction else { return }
            try? await Task.sleep(for: .milliseconds(300))
            handleShortcutAction(action)
            viewModel.send(.shortcutActionConsumed)
        }
        .onChange(of: viewModel.pendingShortcutAction) { _, action in
            guard let action else { return }
            handleShortcutAction(action)
            viewModel.send(.shortcutActionConsumed)
        }
        .task {
            guard viewModel.hasPendingShare else { return }
            try? await Task.sleep(for: .milliseconds(300))
            viewModel.send(.shareItemReceived)
        }
        .onChange(of: viewModel.hasPendingShare) { _, isPending in
            guard isPending else { return }
            viewModel.send(.shareItemReceived)
        }
        .task {
            guard viewModel.pendingURLSchemeAction != nil else { return }
            try? await Task.sleep(for: .milliseconds(300))
            viewModel.send(.urlSchemeActionReceived)
        }
        .onChange(of: viewModel.pendingURLSchemeAction) { _, action in
            guard action != nil else { return }
            viewModel.send(.urlSchemeActionReceived)
        }
#endif
    }
}

// MARK: - Private

private extension HomeView {
#if os(iOS)
    var iOSLayout: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.chats) {
                chatsTab
            } label: {
                Label {
                    Text(String(localized: "Chats"))
                } icon: {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .symbolEffect(.bounce, value: selectedTab)
                }
            }
            Tab(value: AppTab.models) {
                ModelsView()
            } label: {
                Label {
                    Text(String(localized: "Models"))
                } icon: {
                    Image(systemName: "brain.head.profile")
                        .symbolEffect(.bounce, value: selectedTab)
                }
            }
            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                Label {
                    Text(String(localized: "Settings"))
                } icon: {
                    Image(systemName: "gearshape")
                        .symbolEffect(.rotate, value: selectedTab)
                }
            }
            Tab(value: AppTab.search, role: .search) {
                SearchConversationsView()
            } label: {
                Label(String(localized: "Search"), systemImage: "magnifyingglass")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    var chatsTab: some View {
        iPhoneChatsLayout
    }

    var iPhoneChatsLayout: some View {
        NavigationStack {
            ConversationListView(activeConversationId: selectedConversation?.id) { conversation in
                selectedConversation = conversation
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(
                    conversation: conversation,
                    shareItem: viewModel.pendingShareItem,
                    urlSchemeText: viewModel.pendingURLSchemeText,
                    onForkCreated: { fork in
                        selectedConversation = fork
                    },
                    onShareItemProcessed: { viewModel.send(.shareItemConsumed) },
                    onURLSchemeTextProcessed: { viewModel.send(.urlSchemeTextConsumed) }
                )
            }
        }
    }

    // MARK: - AppTab

    enum AppTab: Hashable {
        case chats
        case models
        case settings
        case search
    }

    func handleShortcutAction(_ action: ShortcutAction) {
        switch action {
        case .newChat:
            viewModel.send(.newChatShortcutTriggered)
        case .search:
            selectedTab = .search
        }
    }
#endif

#if os(macOS)
    enum SidebarDestination: Hashable {
        case chats
        case models
        case settings
    }

    var macOSLayout: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .onChange(of: sidebarDestination) { _, _ in
            selectedConversation = nil
        }
    }

    var sidebar: some View {
        List(selection: $sidebarDestination) {
            Section {
                Label(String(localized: "Chats"), systemImage: "bubble.left.and.bubble.right")
                    .tag(SidebarDestination.chats)
            }

            Section {
                Label(String(localized: "Models"), systemImage: "brain.head.profile")
                    .tag(SidebarDestination.models)

                Label(String(localized: "Settings"), systemImage: "gearshape")
                    .tag(SidebarDestination.settings)
            }
        }
        .navigationTitle(String(localized: "OpenClient"))
        .navigationSplitViewColumnWidth(180)
    }

    @ViewBuilder
    var detailContent: some View {
        switch sidebarDestination {
        case .chats:
            NavigationStack {
                ConversationListView(activeConversationId: selectedConversation?.id) { conversation in
                    selectedConversation = conversation
                }
                .navigationDestination(item: $selectedConversation) { conversation in
                    ChatView(
                        conversation: conversation,
                        shareItem: viewModel.pendingShareItem,
                        urlSchemeText: viewModel.pendingURLSchemeText,
                        onForkCreated: { fork in
                            selectedConversation = fork
                        },
                        onShareItemProcessed: { viewModel.send(.shareItemConsumed) },
                        onURLSchemeTextProcessed: { viewModel.send(.urlSchemeTextConsumed) }
                    )
                }
            }
        case .models:
            ModelsView()
        case .settings:
            SettingsView()
        }
    }
#endif
}

// MARK: - Hashable

extension Conversation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    HomeView()
}
