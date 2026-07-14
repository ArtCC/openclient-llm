//
//  ContextUsage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ContextUsage: Equatable, Sendable {
    let estimatedInputTokens: Int
    let maxInputTokens: Int
    let excludedMessageCount: Int
    let compactedMessageCount: Int
    let isLatestTurnOverBudget: Bool

    init(
        estimatedInputTokens: Int,
        maxInputTokens: Int,
        excludedMessageCount: Int = 0,
        compactedMessageCount: Int = 0,
        isLatestTurnOverBudget: Bool = false
    ) {
        self.estimatedInputTokens = estimatedInputTokens
        self.maxInputTokens = maxInputTokens
        self.excludedMessageCount = excludedMessageCount
        self.compactedMessageCount = compactedMessageCount
        self.isLatestTurnOverBudget = isLatestTurnOverBudget
    }

    var percentage: Int {
        guard effectiveMaxInputTokens > 0 else { return 0 }
        return min(100, Int((Double(estimatedInputTokens) / Double(effectiveMaxInputTokens) * 100).rounded()))
    }

    var formattedUsage: String {
        "\(estimatedInputTokens.formatted()) / \(maxInputTokens.formatted())"
    }

    private var effectiveMaxInputTokens: Int {
        let safetyMargin = min(maxInputTokens / 10, max(256, maxInputTokens / 100))
        return max(0, maxInputTokens - safetyMargin)
    }
}
