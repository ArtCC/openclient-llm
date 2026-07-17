//
//  AppCommands.swift
//  openclient-llm-macOS
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct AppCommands: Commands {
    // MARK: - Properties

    @FocusedValue(\.newChatAction) private var newChatAction
    @FocusedValue(\.newPrivateChatAction) private var newPrivateChatAction

    // MARK: - View

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(String(localized: "New Chat")) {
                newChatAction?()
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(newChatAction == nil)

            Button(String(localized: "New Private Chat")) {
                newPrivateChatAction?()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(newPrivateChatAction == nil)

            Divider()
        }
    }
}

// MARK: - FocusedValues

extension FocusedValues {
    @Entry var newChatAction: (() -> Void)?
    @Entry var newPrivateChatAction: (() -> Void)?
}
