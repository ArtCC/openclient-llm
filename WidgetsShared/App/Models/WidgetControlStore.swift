//
//  WidgetControlStore.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - WidgetControlStore

/// Stores one-time requests issued by Control Center in the shared App Group.
enum WidgetControlStore {
    // MARK: - Properties

    static let pendingNewChatRequestKey = "pendingNewChatRequestTimestamp"

    private static let requestLifetime: TimeInterval = 300

    // MARK: - Public

    static func requestNewChat(now: Date = Date()) {
        UserDefaults(suiteName: AppGroupStore.suiteName)?
            .set(now.timeIntervalSince1970, forKey: pendingNewChatRequestKey)
    }

    static func consumePendingNewChat(now: Date = Date()) -> Bool {
        guard let defaults = UserDefaults(suiteName: AppGroupStore.suiteName),
              let timestamp = defaults.object(forKey: pendingNewChatRequestKey) as? Double else {
            return false
        }
        defaults.removeObject(forKey: pendingNewChatRequestKey)

        return timestamp <= now.timeIntervalSince1970
            && now.timeIntervalSince1970 - timestamp <= requestLifetime
    }
}
