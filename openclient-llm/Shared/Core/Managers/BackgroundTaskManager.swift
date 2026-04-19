//
//  BackgroundTaskManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - BackgroundTaskManagerProtocol

protocol BackgroundTaskManagerProtocol {
    func beginTask(expirationHandler: @escaping () -> Void)
    func endTask()
}

// MARK: - BackgroundTaskManager

#if os(iOS)
import SwiftUI

@MainActor
final class BackgroundTaskManager: BackgroundTaskManagerProtocol {
    // MARK: - Properties

    private var taskIdentifier: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Public functions

    func beginTask(expirationHandler: @escaping () -> Void) {
        guard taskIdentifier == .invalid else {
            LogManager.debug("BackgroundTask already running, skipping begin")
            return
        }

        taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "LLMStreaming") { [weak self] in
            LogManager.warning("BackgroundTask expired — streaming time budget exhausted")
            expirationHandler()
            self?.endTask()
        }

        LogManager.debug("BackgroundTask begun id=\(taskIdentifier.rawValue)")
    }

    func endTask() {
        guard taskIdentifier != .invalid else { return }

        LogManager.debug("BackgroundTask ending id=\(taskIdentifier.rawValue)")
        UIApplication.shared.endBackgroundTask(taskIdentifier)
        taskIdentifier = .invalid
    }
}

#else

/// macOS stub — background tasks are not required on macOS.
final class BackgroundTaskManager: BackgroundTaskManagerProtocol {
    func beginTask(expirationHandler: @escaping () -> Void) {}
    func endTask() {}
}

#endif
