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

@MainActor
protocol NotifyStreamingCompletedUseCaseProtocol {
    /// Sends a "response ready" notification only if the app is currently in background.
    func execute()
    /// Sends an "interrupted" notification unconditionally (called when background time expired).
    func executeExpired()
}

// MARK: - NotifyStreamingCompletedUseCase

@MainActor
struct NotifyStreamingCompletedUseCase: NotifyStreamingCompletedUseCaseProtocol {
    // MARK: - Properties

    private let localNotificationManager: LocalNotificationManagerProtocol
    private let isApplicationInBackground: () -> Bool

    // MARK: - Init

    init(
        localNotificationManager: LocalNotificationManagerProtocol = LocalNotificationManager(),
        isApplicationInBackground: (() -> Bool)? = nil
    ) {
        self.localNotificationManager = localNotificationManager
        self.isApplicationInBackground = isApplicationInBackground ?? Self.applicationIsInBackground
    }

    // MARK: - Execute

    func execute() {
        #if os(iOS)
        guard isApplicationInBackground() else { return }
        localNotificationManager.sendCompletionNotification()
        #endif
    }

    func executeExpired() {
        localNotificationManager.sendExpiredNotification()
    }

    // MARK: - Private

    private static func applicationIsInBackground() -> Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .background
        #else
        false
        #endif
    }
}
