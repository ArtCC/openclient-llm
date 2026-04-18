//
//  SearchConversationsIntent.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents
import Foundation

// MARK: - SearchConversationsIntent

/// AppIntent that opens OpenClient and activates the conversation search UI.
///
/// Routing: sets `ShortcutManager.pendingAction = .search`, which `HomeView` picks up
/// via its existing `.onChange(of: viewModel.pendingShortcutAction)` observer.
struct SearchConversationsIntent: AppIntent {
    // MARK: - Metadata

    nonisolated static let title: LocalizedStringResource = "Search Conversations"
    nonisolated static let description = IntentDescription(
        "Opens OpenClient with the conversation search field active."
    )
    nonisolated static let openAppWhenRun: Bool = true

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            ShortcutManager.shared.pendingAction = .search
        }
        return .result()
    }
}
