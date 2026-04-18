//
//  ShareManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - ShareManager

/// Observable singleton that signals the app when the Share Extension has placed
/// a pending item in the shared App Group container.
@Observable
@MainActor
final class ShareManager {
    // MARK: - Properties

    static let shared = ShareManager()

    var hasPendingShare = false

    // MARK: - Init

    private init() {}
}
