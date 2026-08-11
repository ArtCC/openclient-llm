//
//  AppSynchronizationResult.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct AppSynchronizationResult: Equatable, Sendable {
    enum Category: CaseIterable, Hashable, Sendable {
        case conversations
        case profile
        case memory
        case promptTemplates
    }

    enum Outcome: Equatable, Sendable {
        case synchronized
        case pendingDownload
        case unavailable
        case conflict
        case failed
    }

    let outcomes: [Category: Outcome]
    let failureReasons: [Category: CloudSyncStatus.FailureReason]
    let isCancelled: Bool

    init(
        outcomes: [Category: Outcome],
        failureReasons: [Category: CloudSyncStatus.FailureReason] = [:],
        isCancelled: Bool? = nil
    ) {
        self.outcomes = outcomes
        self.failureReasons = failureReasons
        self.isCancelled = isCancelled ?? outcomes.isEmpty
    }

    var isSuccessful: Bool {
        !isCancelled && Category.allCases.allSatisfy { outcomes[$0] == .synchronized }
    }

    func categories(with outcome: Outcome) -> Set<Category> {
        Set(Category.allCases.filter { outcomes[$0] == outcome })
    }

    var cloudSyncIssues: CloudSyncStatus.Issues {
        let pending = Set(categories(with: .pendingDownload).flatMap(\.cloudCategories))
        let unavailable = Dictionary(uniqueKeysWithValues: categories(with: .unavailable).flatMap { category in
            category.cloudCategories.map { ($0, CloudSyncStatus.UnavailableReason.containerUnavailable) }
        })
        let failed = categories(with: .failed).union(categories(with: .conflict))
        let failures = Dictionary(uniqueKeysWithValues: failed.flatMap { category in
            category.cloudCategories.map { ($0, failureReasons[category] ?? .other) }
        })
        return .init(
            pendingCategories: pending,
            unavailableCategories: unavailable,
            failureReasons: failures
        )
    }
}

private extension AppSynchronizationResult.Category {
    nonisolated var cloudCategories: [CloudSyncStatus.DataCategory] {
        switch self {
        case .conversations: [.conversations, .attachments]
        case .profile: [.profile]
        case .memory: [.memory]
        case .promptTemplates: [.promptTemplates]
        }
    }
}
