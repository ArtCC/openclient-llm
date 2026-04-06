//
//  ShortcutManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 06/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ShortcutAction

enum ShortcutAction: String, Sendable {
    case newChat = "com.artcc.openclient-llm.shortcut.newChat"
    case search = "com.artcc.openclient-llm.shortcut.search"
}

// MARK: - ShortcutManager

@Observable
@MainActor
final class ShortcutManager {
    // MARK: - Properties

    static let shared = ShortcutManager()

    var pendingAction: ShortcutAction?

    // MARK: - Init

    private init() {}
}
