//
//  AppGroupStore.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - AppGroupStore

/// Reads and writes widget snapshot data to the shared App Group container.
/// Both the main app (writes) and the Widgets extension (reads) use this type.
enum AppGroupStore {
    // MARK: - Properties

    static let suiteName = "group.com.artcc.openclient-llm"
    static let conversationsWidgetKind = "com.artcc.openclient-llm.widget.conversations-overview"

    private static let conversationsKey = "widgetConversations"

    // MARK: - Public

    @discardableResult
    static func saveConversations(_ conversations: [WidgetConversation]) -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? encoder.encode(conversations) else { return false }
        if let currentData = defaults.data(forKey: conversationsKey),
           let currentConversations = try? decoder.decode([WidgetConversation].self, from: currentData),
           let newConversations = try? decoder.decode([WidgetConversation].self, from: data),
           currentConversations == newConversations {
            return false
        }
        defaults.set(data, forKey: conversationsKey)
        return true
    }

    static func loadConversations() -> [WidgetConversation] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: conversationsKey),
              let conversations = try? decoder.decode([WidgetConversation].self, from: data) else {
            return []
        }
        return conversations
    }

    @discardableResult
    static func clearConversations() -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              defaults.object(forKey: conversationsKey) != nil else { return false }
        defaults.removeObject(forKey: conversationsKey)
        return true
    }
}

// MARK: - Private

private extension AppGroupStore {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
