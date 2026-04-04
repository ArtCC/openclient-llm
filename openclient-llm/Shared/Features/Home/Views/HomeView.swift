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

    @State private var selectedConversation: Conversation?
    @State private var conversationListId = UUID()

    #if os(macOS)
    @State private var sidebarDestination: SidebarDestination = .chats
    #endif

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab = .chats
    #endif

    // MARK: - View

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
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
    }

    var chatsTab: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadChatsLayout
            } else {
                iPhoneChatsLayout
            }
        }
    }

    var iPhoneChatsLayout: some View {
        NavigationStack {
            ConversationListView(activeConversationId: selectedConversation?.id) { conversation in
                selectedConversation = conversation
            }
            .id(conversationListId)
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(
                    conversation: conversation,
                    onConversationUpdated: {
                        conversationListId = UUID()
                    },
                    onForkCreated: { fork in
                        selectedConversation = fork
                        conversationListId = UUID()
                    }
                )
            }
        }
    }

    var iPadChatsLayout: some View {
        NavigationSplitView {
            ConversationListView(activeConversationId: selectedConversation?.id) { conversation in
                selectedConversation = conversation
            }
            .id(conversationListId)
            .navigationSplitViewColumnWidth(320)
        } detail: {
            if let selectedConversation {
                ChatView(
                    conversation: selectedConversation,
                    onConversationUpdated: {
                        conversationListId = UUID()
                    },
                    onForkCreated: { fork in
                        self.selectedConversation = fork
                        conversationListId = UUID()
                    }
                )
            } else {
                ContentUnavailableView(
                    String(localized: "No Conversation Selected"),
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text(String(localized: "Select or create a conversation to start chatting"))
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
                .id(conversationListId)
                .navigationDestination(item: $selectedConversation) { conversation in
                    ChatView(
                        conversation: conversation,
                        onConversationUpdated: {
                            conversationListId = UUID()
                        },
                        onForkCreated: { fork in
                            selectedConversation = fork
                            conversationListId = UUID()
                        }
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
