//
//  LocalNotificationManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import UserNotifications

// MARK: - NotificationPermissionStatus

enum NotificationPermissionStatus: Equatable {
    case authorized
    case denied
    case notDetermined
}

// MARK: - LocalNotificationManagerProtocol

protocol LocalNotificationManagerProtocol {
    func requestAuthorization() async
    func sendCompletionNotification()
    func sendExpiredNotification()
}

// MARK: - LocalNotificationManager

/// Stateless — safe to use as @unchecked Sendable (UNUserNotificationCenter is internally thread-safe).
final class LocalNotificationManager: LocalNotificationManagerProtocol, @unchecked Sendable {
    // MARK: - Public functions

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            LogManager.info("Notification permission granted=\(granted)")
        } catch {
            LogManager.error("Notification permission failed: \(error)")
        }
    }

    func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Response ready")
        content.body = String(localized: "The model finished responding. Tap to continue.")
        content.sound = .default

        schedule(content: content)
    }

    func sendExpiredNotification() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Response interrupted")
        content.body = String(localized: "The response was cut short. Open the app to see what was received.")
        content.sound = .default

        schedule(content: content)
    }

    // MARK: - Private functions

    private func schedule(content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Task { @MainActor in
                    LogManager.error("Notification scheduling failed: \(error)")
                }
            }
        }
    }
}
