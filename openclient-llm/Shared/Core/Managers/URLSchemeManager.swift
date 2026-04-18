//
//  URLSchemeManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - URLSchemeManager

/// Holds the pending deep-link action until `HomeViewModel` can process it.
@Observable
@MainActor
final class URLSchemeManager {
    // MARK: - Singleton

    static let shared = URLSchemeManager()

    // MARK: - Properties

    var pendingAction: URLSchemeAction?

    // MARK: - Init

    private init() {}
}
