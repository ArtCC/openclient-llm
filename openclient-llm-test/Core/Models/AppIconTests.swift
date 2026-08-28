//
//  AppIconTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import UIKit
import XCTest
@testable import openclient_llm

@MainActor
final class AppIconTests: XCTestCase {
    func test_allCases_containsThirtyIcons() {
        // When
        let icons = AppIcon.allCases

        // Then
        XCTAssertEqual(icons.count, 30)
    }

    func test_icons_eachCategory_containsFiveIcons() {
        // When
        let categoryCounts = AppIcon.Category.allCases.map { AppIcon.icons(in: $0).count }

        // Then
        XCTAssertEqual(categoryCounts, [5, 5, 5, 5, 5, 5])
    }

    func test_alternateIconName_defaultIcon_returnsNil() {
        // When
        let alternateIconName = AppIcon.defaultIcon.alternateIconName

        // Then
        XCTAssertNil(alternateIconName)
    }

    func test_init_unknownAlternateIconName_returnsDefaultIcon() {
        // When
        let icon = AppIcon(alternateIconName: "Unknown")

        // Then
        XCTAssertEqual(icon, .defaultIcon)
    }

    func test_visibleCategories_missingConfiguration_returnsAllCategories() {
        // When
        let categories = AppIcon.Category.visibleCategories(showIconPacks: nil)

        // Then
        XCTAssertEqual(categories, AppIcon.Category.allCases)
    }

    func test_visibleCategories_configured_returnsOpenClientAndKnownPacks() {
        // When
        let categories = AppIcon.Category.visibleCategories(
            showIconPacks: ["christmas", "colors", "unknown"]
        )

        // Then
        XCTAssertEqual(categories, [.openClient, .colors, .christmas])
    }

    func test_visibleCategories_emptyConfiguration_returnsOpenClient() {
        // When
        let categories = AppIcon.Category.visibleCategories(showIconPacks: [])

        // Then
        XCTAssertEqual(categories, [.openClient])
    }

    func test_previewImage_allIcons_loadFromMainBundle() {
        // When
        let missingIcons = AppIcon.allCases.filter { icon in
            guard let url = Bundle.main.url(forResource: icon.rawValue, withExtension: "png") else { return true }
            return UIImage(contentsOfFile: url.path) == nil
        }

        // Then
        XCTAssertTrue(missingIcons.isEmpty, "Missing icon previews: \(missingIcons.map(\.rawValue))")
    }
}
