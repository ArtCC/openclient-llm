//
//  NotifyStreamingCompletedUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#endif

// MARK: - NotifyStreamingCompletedUseCaseProtocol

protocol NotifyStreamingCompletedUseCaseProtocol: Sendable {
    /// Sends a "response ready" notification only if the app is currently in background.
    func execute() async
    /// Sends an "interrupted" notification unconditionally (called when background time expired).
    func executeExpired() async
}

// MARK: - NotifyStreamingCompletedUseCase

/// @unchecked Sendable — LocalNotificationManager has no mutable state;
/// UNUserNotificationCenter is internally thread-safe.
struct NotifyStreamingCompletedUseCase: NotifyStreamingCompletedUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let localNotificationManager: LocalNotificationManager

    // MARK: - Init

    init(localNotificationManager: LocalNotificationManager = LocalNotificationManager()) {
        self.localNotificationManager = localNotificationManager
    }

    // MARK: - Execute

    func execute() async {
        #if os(iOS)
        let isBackground = await MainActor.run {
            UIApplication.shared.applicationState == .background
        }
        guard isBackground else { return }
        localNotificationManager.sendCompletionNotification()
        #endif
    }

    func executeExpired() async {
        localNotificationManager.sendExpiredNotification()
    }
}
