//
//  NewChatControlIntent.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents
import Foundation

// MARK: - NewChatControlIntent

/// AppIntent used by the Control Center widget to open OpenClient in a blank new conversation.
/// Self-contained — does not depend on any app-target code.
/// Opens the app via the `openclient://new-chat` URL scheme.
struct NewChatControlIntent: AppIntent {
    // MARK: - Metadata

    nonisolated static let title: LocalizedStringResource = "New Chat"
    nonisolated static let description = IntentDescription("Opens OpenClient and starts a new conversation.")
    nonisolated static let openAppWhenRun: Bool = true

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        .result()
    }
}
