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

    var isSuccessful: Bool {
        Category.allCases.allSatisfy { outcomes[$0] == .synchronized }
    }

    func categories(with outcome: Outcome) -> Set<Category> {
        Set(Category.allCases.filter { outcomes[$0] == outcome })
    }
}
