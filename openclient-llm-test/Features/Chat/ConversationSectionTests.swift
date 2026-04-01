//
//  ConversationSectionTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ConversationSectionTests: XCTestCase {
    // MARK: - Tests — group pinned

    func test_group_pinnedConversationAppearsInPinnedSection() {
        // Given
        let pinned = Conversation(modelId: "gpt-4", isPinned: true)
        let unpinned = Conversation(modelId: "gpt-4", isPinned: false)

        // When
        let sections = ConversationSection.group([pinned, unpinned])

        // Then
        let pinnedSection = sections.first(where: { $0.period == .pinned })
        XCTAssertNotNil(pinnedSection)
        XCTAssertEqual(pinnedSection?.conversations.count, 1)
        XCTAssertEqual(pinnedSection?.conversations.first?.id, pinned.id)
    }

    func test_group_noPinnedConversations_noPinnedSection() {
        // Given
        let conversations = [
            Conversation(modelId: "gpt-4", isPinned: false),
            Conversation(modelId: "llama3", isPinned: false)
        ]

        // When
        let sections = ConversationSection.group(conversations)

        // Then
        let pinnedSection = sections.first(where: { $0.period == .pinned })
        XCTAssertNil(pinnedSection)
    }

    func test_group_pinnedSectionIsFirst() {
        // Given
        let pinned = Conversation(modelId: "gpt-4", isPinned: true)

        // When
        let sections = ConversationSection.group([pinned])

        // Then
        XCTAssertEqual(sections.first?.period, .pinned)
    }

    func test_group_pinnedConversationNotInOtherSections() {
        // Given
        let pinned = Conversation(modelId: "gpt-4", isPinned: true)

        // When
        let sections = ConversationSection.group([pinned])

        // Then
        let nonPinnedSections = sections.filter { $0.period != .pinned }
        XCTAssertTrue(nonPinnedSections.allSatisfy { section in
            !section.conversations.contains(where: { $0.id == pinned.id })
        })
    }

    // MARK: - Tests — group by date

    func test_group_emptyInput_returnsEmptySections() {
        XCTAssertTrue(ConversationSection.group([]).isEmpty)
    }

    func test_group_todayConversationAppearsInTodaySection() {
        // Given
        let conversation = Conversation(modelId: "gpt-4", updatedAt: Date())

        // When
        let sections = ConversationSection.group([conversation])

        // Then
        let todaySection = sections.first(where: { $0.period == .today })
        XCTAssertNotNil(todaySection)
        XCTAssertEqual(todaySection?.conversations.first?.id, conversation.id)
    }
}
