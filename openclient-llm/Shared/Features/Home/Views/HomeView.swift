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
    #endif

    #if os(macOS)
    var macOSLayout: some View {
        NavigationSplitView {
            List {
                Section {
                    NavigationLink {
                        macOSChatsView
                    } label: {
                        Label(String(localized: "Chats"), systemImage: "bubble.left.and.bubble.right")
                    }

                    NavigationLink {
                        ModelsView()
                    } label: {
                        Label(String(localized: "Models"), systemImage: "cpu")
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(String(localized: "Settings"), systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle(String(localized: "OpenClient"))
        } detail: {
            macOSChatsView
        }
    }

    var macOSChatsView: some View {
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
