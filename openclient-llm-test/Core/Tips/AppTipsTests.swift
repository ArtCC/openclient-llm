//
//  AppTipsTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import TipKit
import XCTest
@testable import openclient_llm

@MainActor
final class AppTipsTests: XCTestCase {
    func test_allTips_containsEveryFeatureTip() {
        // Given
        let expectedCount = 10

        // When
        let tips = AppTips.allTips

        // Then
        XCTAssertEqual(tips.count, expectedCount)
    }

    func test_allTips_haveUniqueIdentifiers() {
        // Given
        let tips = AppTips.allTips

        // When
        let identifiers = Set(tips.map(\.id))

        // Then
        XCTAssertEqual(identifiers.count, tips.count)
    }

    func test_allTips_haveNoActions() {
        // Given
        let tips = AppTips.allTips

        // When
        let containsActions = tips.contains { !$0.actions.isEmpty }

        // Then
        XCTAssertFalse(containsActions)
    }
}
