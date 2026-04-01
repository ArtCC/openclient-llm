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
