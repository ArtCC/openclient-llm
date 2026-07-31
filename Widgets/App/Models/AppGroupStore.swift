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
    static let pinnedConversationsWidgetKind = "com.artcc.openclient-llm.widget.pinned-conversations"
    static let latestConversationWidgetKind = "com.artcc.openclient-llm.widget.latest-conversation"

    private static let conversationsKey = "widgetConversations"
    private static let pinnedConversationsKey = "widgetPinnedConversations"

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
    static func savePinnedConversations(_ conversations: [WidgetConversation]) -> Bool {
        save(conversations, forKey: pinnedConversationsKey)
    }

    static func loadPinnedConversations() -> [WidgetConversation] {
        load(forKey: pinnedConversationsKey)
    }

    @discardableResult
    static func clearConversations() -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return false }
        let hasConversations = defaults.object(forKey: conversationsKey) != nil
        let hasPinnedConversations = defaults.object(forKey: pinnedConversationsKey) != nil
        guard hasConversations || hasPinnedConversations else { return false }
        defaults.removeObject(forKey: conversationsKey)
        defaults.removeObject(forKey: pinnedConversationsKey)
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

    @discardableResult
    static func save(_ conversations: [WidgetConversation], forKey key: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? encoder.encode(conversations) else { return false }
        if let currentData = defaults.data(forKey: key),
           let currentConversations = try? decoder.decode([WidgetConversation].self, from: currentData),
           let newConversations = try? decoder.decode([WidgetConversation].self, from: data),
           currentConversations == newConversations {
            return false
        }
        defaults.set(data, forKey: key)
        return true
    }

    static func load(forKey key: String) -> [WidgetConversation] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let conversations = try? decoder.decode([WidgetConversation].self, from: data) else {
            return []
        }
        return conversations
    }
}
