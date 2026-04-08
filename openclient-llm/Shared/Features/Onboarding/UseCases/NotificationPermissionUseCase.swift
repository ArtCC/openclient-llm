//
//  NotificationPermissionUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - NotificationPermissionUseCaseProtocol

protocol NotificationPermissionUseCaseProtocol: Sendable {
    func execute() async
}

// MARK: - NotificationPermissionUseCase

/// @unchecked Sendable — LocalNotificationManager has no mutable state;
/// UNUserNotificationCenter is internally thread-safe.
struct NotificationPermissionUseCase: NotificationPermissionUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    private let localNotificationManager: LocalNotificationManager

    // MARK: - Init

    init(localNotificationManager: LocalNotificationManager = LocalNotificationManager()) {
        self.localNotificationManager = localNotificationManager
    }

    // MARK: - Execute

    func execute() async {
        await localNotificationManager.requestAuthorization()
    }
}
