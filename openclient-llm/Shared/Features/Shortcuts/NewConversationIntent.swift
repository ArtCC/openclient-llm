//
//  NewConversationIntent.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents
import Foundation

// MARK: - NewConversationIntent

/// AppIntent that opens OpenClient and starts a new conversation.
/// An optional pre-filled message can be provided.
///
/// Routing:
/// - With message: sets `URLSchemeManager.pendingAction = .chat(text:url:)` so `HomeViewModel`
///   creates a new conversation and pre-fills the input field via the existing URL-scheme flow.
/// - Without message: sets `ShortcutManager.pendingAction = .newChat` for plain new-chat navigation.
struct NewConversationIntent: AppIntent {
    // MARK: - Metadata

    nonisolated static let title: LocalizedStringResource = "New Conversation"
    nonisolated static let description = IntentDescription("Opens OpenClient and starts a new conversation.")
    nonisolated static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(title: "Message")
    var message: String?

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            if let text = message, !text.isEmpty {
                URLSchemeManager.shared.pendingAction = .chat(text: text, url: nil)
            } else {
                ShortcutManager.shared.pendingAction = .newChat
            }
        }
        return .result()
    }
}
