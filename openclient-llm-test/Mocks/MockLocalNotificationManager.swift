//
//  MockLocalNotificationManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 27/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

final class MockLocalNotificationManager: LocalNotificationManagerProtocol {
    private(set) var completionCallCount = 0
    private(set) var expirationCallCount = 0

    func requestAuthorization() async {}

    func sendCompletionNotification() {
        completionCallCount += 1
    }

    func sendExpiredNotification() {
        expirationCallCount += 1
    }
}
