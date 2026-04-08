//
//  CheckNotificationPermissionUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import UserNotifications

// MARK: - NotificationStatusCheckProtocol

protocol NotificationStatusCheckProtocol: Sendable {
    func execute() async -> NotificationPermissionStatus
}

// MARK: - CheckNotificationPermissionUseCase

struct CheckNotificationPermissionUseCase: NotificationStatusCheckProtocol {
    // MARK: - Execute

    func execute() async -> NotificationPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
}
