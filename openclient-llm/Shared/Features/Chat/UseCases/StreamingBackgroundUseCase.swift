//
//  StreamingBackgroundUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - StreamingBackgroundUseCaseProtocol

protocol StreamingBackgroundUseCaseProtocol: AnyObject {
    func begin(expirationHandler: @escaping () -> Void)
    func end()
}

// MARK: - StreamingBackgroundUseCase

/// Class-based use case because it wraps a stateful manager (UIBackgroundTaskIdentifier lifecycle).
/// Isolated to @MainActor — safe to call from ChatViewModel without Sendable concerns.
@MainActor
final class StreamingBackgroundUseCase: StreamingBackgroundUseCaseProtocol {
    // MARK: - Properties

    private let backgroundTaskManager: BackgroundTaskManager

    // MARK: - Init

    init(backgroundTaskManager: BackgroundTaskManager = BackgroundTaskManager()) {
        self.backgroundTaskManager = backgroundTaskManager
    }

    // MARK: - Execute

    func begin(expirationHandler: @escaping () -> Void) {
        backgroundTaskManager.beginTask(expirationHandler: expirationHandler)
    }

    func end() {
        backgroundTaskManager.endTask()
    }
}
