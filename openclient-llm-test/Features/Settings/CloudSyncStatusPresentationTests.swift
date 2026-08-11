//
//  CloudSyncStatusPresentationTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudSyncStatusPresentationTests: XCTestCase {
    func test_make_failedConversations_namesAttachmentsAsConversationChildren() {
        // Given
        let status = CloudSyncStatus.failed(.init(
            reason: .other,
            affectedCategories: [.conversations, .attachments]
        ))

        // When
        let presentation = CloudSyncStatusPresentation.make(for: status)

        // Then
        XCTAssertTrue(presentation.detail?.contains("Attachments (part of conversations)") == true)
        XCTAssertTrue(presentation.canRetry)
    }

    func test_make_profileConflict_usesProfileOnlyWordingAndOffersRetry() {
        // Given
        let status = CloudSyncStatus.failed(.init(reason: .profileConflict, affectedCategories: [.profile]))

        // When
        let presentation = CloudSyncStatusPresentation.make(for: status)

        // Then
        XCTAssertTrue(presentation.title.contains("Profile"))
        XCTAssertTrue(presentation.canRetry)
    }

    func test_make_accountChanged_requiresAccessibleAccountReviewAction() {
        // Given
        let status = CloudSyncStatus.failed(.init(
            reason: .accountChanged,
            affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
        ))

        // When
        let presentation = CloudSyncStatusPresentation.make(for: status)

        // Then
        XCTAssertTrue(presentation.title.contains("iCloud account"))
        XCTAssertTrue(presentation.requiresAccountReview)
        XCTAssertTrue(presentation.canRetry)
    }

    func test_make_mixedIssues_presentsFailuresPendingAndUnavailableDeterministically() {
        // Given
        let status = CloudSyncStatus.incomplete(.init(
            pendingCategories: [.promptTemplates],
            unavailableCategories: [.profile: .accountUnavailable],
            failureReasons: [.memory: .invalidData, .conversations: .fileAccess]
        ))

        // When
        let presentation = CloudSyncStatusPresentation.make(for: status)

        // Then
        XCTAssertTrue(presentation.detail?.contains(String(
            format: String(localized: "%@: %@."),
            String(localized: "iCloud file access failed"),
            String(localized: "Conversations")
        )) == true)
        XCTAssertTrue(presentation.detail?.contains(String(
            format: String(localized: "%@: %@."),
            String(localized: "Invalid synchronized data"),
            String(localized: "Memory")
        )) == true)
        XCTAssertTrue(presentation.detail?.contains(String(
            format: String(localized: "Waiting for iCloud downloads for: %@."),
            String(localized: "Prompt templates")
        )) == true)
        XCTAssertTrue(presentation.detail?.contains(String(
            format: String(localized: "%@: %@."),
            String(localized: "iCloud account unavailable"),
            String(localized: "Profile")
        )) == true)
    }
}
