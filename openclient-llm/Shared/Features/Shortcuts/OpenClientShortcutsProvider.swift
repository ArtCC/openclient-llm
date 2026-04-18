//
//  OpenClientShortcutsProvider.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents

// MARK: - OpenClientShortcutsProvider

/// Registers the app's predefined Apple Shortcuts so they appear automatically
/// in the Shortcuts app and are available as Siri phrases.
///
/// Each `AppShortcut` must contain `\(.applicationName)` in at least one phrase
/// so Siri can activate it by name. Phrases are kept short and unambiguous.
struct OpenClientShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewConversationIntent(),
            phrases: [
                "New chat in \(.applicationName)",
                "Start a conversation in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "New Chat",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
        AppShortcut(
            intent: SearchConversationsIntent(),
            phrases: [
                "Search chats in \(.applicationName)",
                "Find conversation in \(.applicationName)"
            ],
            shortTitle: "Search Chats",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: SendFileToChatIntent(),
            phrases: [
                "Send file to \(.applicationName)",
                "Share file with \(.applicationName)"
            ],
            shortTitle: "Send File to Chat",
            systemImageName: "doc.badge.arrow.up"
        )
    }
}
