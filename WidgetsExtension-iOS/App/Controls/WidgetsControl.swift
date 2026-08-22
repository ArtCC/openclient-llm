//
//  WidgetsControl.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - NewChatControlWidget

/// Control Center widget (iOS 18+) that provides a one-tap shortcut to open
/// OpenClient in a blank new conversation.
/// The user adds it manually via Settings → Control Center → Customize Controls.
struct NewChatControlWidget: ControlWidget {
    // MARK: - Properties

    static let kind: String = "com.artcc.openclient-llm.control.new-chat"

    // MARK: - Body

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: NewChatControlIntent()) {
                Label("New Chat", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .displayName("New Chat")
        .description("Opens a new conversation in OpenClient.")
    }
}
