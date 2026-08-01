//
//  TaggedConversationsWidgetIntent.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 01/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppIntents

// MARK: - TaggedConversationsWidgetIntent

struct TaggedConversationsWidgetIntent: WidgetConfigurationIntent {
    // MARK: - Properties

    nonisolated static let title: LocalizedStringResource = "Tagged Conversations"
    nonisolated static let description = IntentDescription("Choose the tag shown by the conversations widget.")

    @Parameter(title: "Tag", optionsProvider: ConversationTagOptionsProvider())
    var tag: String?

    // MARK: - Init

    init() {
        tag = String(localized: "All Tags")
    }
}

// MARK: - ConversationTagOptionsProvider

struct ConversationTagOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        [String(localized: "All Tags")] + AppGroupStore.loadTags()
    }
}
