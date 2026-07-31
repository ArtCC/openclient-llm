//
//  ContextUsageTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ContextUsageTests: XCTestCase {
    // MARK: - Tests — percentage

    func test_percentage_zeroMaxInputTokens_returnsZero() {
        let usage = ContextUsage(estimatedInputTokens: 500, maxInputTokens: 0)
        XCTAssertEqual(usage.percentage, 0)
    }

    func test_percentage_fullUsage_returnsOneHundred() {
        let usage = ContextUsage(estimatedInputTokens: 1000, maxInputTokens: 1000)
        let percentage = usage.percentage
        XCTAssertTrue(percentage > 90, "Expected near 100%, got \(percentage)")
    }

    func test_percentage_halfUsage_returnsFifty() {
        let usage = ContextUsage(estimatedInputTokens: 500, maxInputTokens: 1000)
        let percentage = usage.percentage
        XCTAssertGreaterThan(percentage, 40)
        XCTAssertLessThan(percentage, 70)
    }

    func test_percentage_incorporatesSafetyMargin() {
        // With maxInputTokens=1000, safetyMargin = min(100, max(256, 10)) = 100
        // effectiveMaxInputTokens = 1000 - 100 = 900
        // 450 / 900 * 100 = 50
        let usage = ContextUsage(estimatedInputTokens: 450, maxInputTokens: 1000)
        XCTAssertEqual(usage.percentage, 50)
    }

    func test_percentage_smallTokenLimit_usesMinimumSafetyMargin() {
        // With maxInputTokens=2560, safetyMargin = min(256, max(256, 25)) = 256
        // effectiveMaxInputTokens = 2560 - 256 = 2304
        let usage = ContextUsage(estimatedInputTokens: 0, maxInputTokens: 2560)
        XCTAssertEqual(usage.percentage, 0)
    }

    func test_percentage_clampedToMax() {
        let usage = ContextUsage(estimatedInputTokens: 2000, maxInputTokens: 100)
        XCTAssertEqual(usage.percentage, 100)
    }

    // MARK: - Tests — formattedUsage

    func test_formattedUsage_hasExpectedFormat() {
        let usage = ContextUsage(estimatedInputTokens: 500, maxInputTokens: 4096)
        let parts = usage.formattedUsage.components(separatedBy: " / ")
        XCTAssertEqual(parts.count, 2)
        XCTAssertFalse(parts[0].isEmpty)
        XCTAssertFalse(parts[1].isEmpty)
    }

    // MARK: - Tests — edge cases

    func test_excludedAndCompactedMessageCounts_defaultToZero() {
        let usage = ContextUsage(estimatedInputTokens: 100, maxInputTokens: 1000)
        XCTAssertEqual(usage.excludedMessageCount, 0)
        XCTAssertEqual(usage.compactedMessageCount, 0)
    }

    func test_isLatestTurnOverBudget_defaultsToFalse() {
        let usage = ContextUsage(estimatedInputTokens: 100, maxInputTokens: 1000)
        XCTAssertFalse(usage.isLatestTurnOverBudget)
    }

    func test_equatable_sameValues_areEqual() {
        let usageA = ContextUsage(estimatedInputTokens: 100, maxInputTokens: 1000)
        let usageB = ContextUsage(estimatedInputTokens: 100, maxInputTokens: 1000)
        XCTAssertEqual(usageA, usageB)
    }

    func test_equatable_differentEstimates_areNotEqual() {
        let usageA = ContextUsage(estimatedInputTokens: 100, maxInputTokens: 1000)
        let usageB = ContextUsage(estimatedInputTokens: 200, maxInputTokens: 1000)
        XCTAssertNotEqual(usageA, usageB)
    }
}
