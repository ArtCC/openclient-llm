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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
        TabView {
            Tab(String(localized: "Chats"), systemImage: "bubble.left.and.bubble.right") {
                chatsTab
            }
            Tab(String(localized: "Models"), systemImage: "cpu") {
                ModelsView()
            }
            Tab(String(localized: "Settings"), systemImage: "gearshape") {
                SettingsView()
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
            ConversationListView { conversation in
                selectedConversation = conversation
            }
            .id(conversationListId)
            .navigationTitle(String(localized: "Chats"))
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(
                    conversation: conversation,
                    onConversationUpdated: {
                        conversationListId = UUID()
                    }
                )
            }
        }
    }

    var iPadChatsLayout: some View {
        NavigationSplitView {
            ConversationListView { conversation in
                selectedConversation = conversation
            }
            .id(conversationListId)
            .navigationTitle(String(localized: "Chats"))
        } detail: {
            if let selectedConversation {
                ChatView(
                    conversation: selectedConversation,
                    onConversationUpdated: {
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
    #endif

    #if os(macOS)
    enum SidebarDestination: Hashable {
        case chats
        case models
        case settings
    }

    var macOSLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } content: {
            sidebarContent
        } detail: {
            detailContent
        }
        .onChange(of: sidebarDestination) { _, newValue in
            columnVisibility = newValue == .chats ? .all : .doubleColumn
        }
    }

    var sidebar: some View {
        List(selection: $sidebarDestination) {
            Section {
                Label(String(localized: "Chats"), systemImage: "bubble.left.and.bubble.right")
                    .tag(SidebarDestination.chats)
            }

            Section {
                Label(String(localized: "Models"), systemImage: "cpu")
                    .tag(SidebarDestination.models)

                Label(String(localized: "Settings"), systemImage: "gearshape")
                    .tag(SidebarDestination.settings)
            }
        }
        .navigationTitle(String(localized: "OpenClient"))
    }

    @ViewBuilder
    var sidebarContent: some View {
        switch sidebarDestination {
        case .chats:
            ConversationListView { conversation in
                selectedConversation = conversation
            }
            .id(conversationListId)
            .navigationTitle(String(localized: "Chats"))
        case .models, .settings:
            // These sections are rendered directly in the detail column;
            // the content column is hidden via .doubleColumn visibility.
            EmptyView()
        }
    }

    @ViewBuilder
    var detailContent: some View {
        switch sidebarDestination {
        case .chats:
            if let selectedConversation {
                ChatView(
                    conversation: selectedConversation,
                    onConversationUpdated: {
                        conversationListId = UUID()
                    }
                )
            } else {
                chatEmptyDetail
            }
        case .models:
            ModelsView()
        case .settings:
            SettingsView()
        }
    }

    var chatEmptyDetail: some View {
        ContentUnavailableView(
            String(localized: "No Conversation Selected"),
            systemImage: "bubble.left.and.bubble.right",
            description: Text(String(localized: "Select or create a conversation to start chatting"))
        )
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
