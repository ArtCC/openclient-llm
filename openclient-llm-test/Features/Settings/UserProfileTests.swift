//
//  UserProfileTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class UserProfileTests: XCTestCase {
    // MARK: - Tests — isEmpty

    func test_isEmpty_trueForDefaultProfile() {
        XCTAssertTrue(UserProfile().isEmpty)
    }

    func test_isEmpty_falseWhenNameIsSet() {
        XCTAssertFalse(UserProfile(name: "Alice").isEmpty)
    }

    func test_isEmpty_falseWhenDescriptionIsSet() {
        XCTAssertFalse(UserProfile(profileDescription: "Developer").isEmpty)
    }

    func test_decode_legacyProfileWithoutModificationDate_usesDistantPastRevision() throws {
        // Given
        let data = Data(#"{"name":"Alice","profileDescription":"Developer","extraInfo":"Swift"}"#.utf8)

        // When
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)

        // Then
        XCTAssertEqual(profile.modifiedAt, .distantPast)
    }

    func test_decode_shippedISO8601Profile_preservesCompatibility() throws {
        // Given
        let data = Data(
            #"""
            {
              "name": "Alice",
              "profileDescription": "Developer",
              "extraInfo": "Swift",
              "modifiedAt": "2026-08-11T12:34:56Z"
            }
            """#.utf8
        )

        // When
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)

        // Then
        XCTAssertEqual(profile.modifiedAt, Date(timeIntervalSince1970: 1_786_451_696))
    }

    func test_init_submillisecondRevision_matchesPersistedRoundTrip() throws {
        // Given
        let profile = UserProfile(
            name: "Alice",
            modifiedAt: Date(timeIntervalSince1970: 1_786_460_550.288_004)
        )

        // When
        let data = try SyncJSONCoding.makeEncoder().encode(profile)
        let decoded = try SyncJSONCoding.makeDecoder().decode(UserProfile.self, from: data)

        // Then
        XCTAssertEqual(decoded, profile)
    }

    // MARK: - Tests — systemPromptContext

    func test_systemPromptContext_emptyProfileReturnsEmptyString() {
        XCTAssertEqual(UserProfile().systemPromptContext, "")
    }

    func test_systemPromptContext_withNameOnly() {
        let profile = UserProfile(name: "Alice")
        XCTAssertTrue(profile.systemPromptContext.contains("Alice"))
    }

    func test_systemPromptContext_withAllFields_containsAllParts() {
        let profile = UserProfile(
            name: "Alice",
            profileDescription: "iOS Developer",
            extraInfo: "Prefers concise answers"
        )
        let context = profile.systemPromptContext
        XCTAssertTrue(context.contains("Alice"))
        XCTAssertTrue(context.contains("iOS Developer"))
        XCTAssertTrue(context.contains("Prefers concise answers"))
    }

    func test_systemPromptContext_whitespaceOnlyFieldsAreIgnored() {
        let profile = UserProfile(name: "   ", profileDescription: "   ", extraInfo: "   ")
        XCTAssertEqual(profile.systemPromptContext, "")
    }
}
