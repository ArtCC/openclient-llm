//
//  ConversationSection.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ConversationSection: Equatable, Identifiable {
    // MARK: - Properties

    enum Period: String, Equatable {
        case pinned
        case today
        case yesterday
        case thisWeek
        case earlier

        var localizedTitle: String {
            switch self {
            case .pinned: String(localized: "Pinned")
            case .today: String(localized: "Today")
            case .yesterday: String(localized: "Yesterday")
            case .thisWeek: String(localized: "This Week")
            case .earlier: String(localized: "Earlier")
            }
        }
    }

    let period: Period
    let conversations: [Conversation]

    var id: String { period.rawValue }

    // MARK: - Factory

    static func group(_ conversations: [Conversation]) -> [ConversationSection] {
        let calendar = Calendar.current
        let now = Date()

        let pinned = conversations.filter(\.isPinned)
        let unpinned = conversations.filter { !$0.isPinned }

        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var thisWeek: [Conversation] = []
        var earlier: [Conversation] = []

        for conversation in unpinned {
            let date = conversation.updatedAt
            if calendar.isDateInToday(date) {
                today.append(conversation)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(conversation)
            } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
                thisWeek.append(conversation)
            } else {
                earlier.append(conversation)
            }
        }

        return [
            ConversationSection(period: .pinned, conversations: pinned),
            ConversationSection(period: .today, conversations: today),
            ConversationSection(period: .yesterday, conversations: yesterday),
            ConversationSection(period: .thisWeek, conversations: thisWeek),
            ConversationSection(period: .earlier, conversations: earlier)
        ].filter { !$0.conversations.isEmpty }
    }
}
