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

    // MARK: - View

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(String(localized: "New Chat")) {
                newChatAction?()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(newChatAction == nil)

            Divider()
        }
    }
}

// MARK: - FocusedValues

extension FocusedValues {
    @Entry var newChatAction: (() -> Void)?
}
