//
//  GetUserProfileContextUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class GetUserProfileContextUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: GetUserProfileContextUseCase!
    private var mockUserProfileManager: MockUserProfileManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockUserProfileManager = MockUserProfileManager()
        sut = GetUserProfileContextUseCase(manager: mockUserProfileManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockUserProfileManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — execute

    func test_execute_emptyProfile_returnsEmptyString() {
        // Given
        mockUserProfileManager.profile = UserProfile()

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_withName_returnsNameContext() {
        // Given
        mockUserProfileManager.profile = UserProfile(name: "Alice")

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.contains("Alice"))
    }

    func test_execute_withDescription_returnsDescriptionContext() {
        // Given
        mockUserProfileManager.profile = UserProfile(profileDescription: "Swift developer")

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.contains("Swift developer"))
    }

    func test_execute_withExtraInfo_returnsExtraInfoContext() {
        // Given
        mockUserProfileManager.profile = UserProfile(extraInfo: "Works at Acme")

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.contains("Acme"))
    }

    func test_execute_withFullProfile_returnsAllFields() {
        // Given
        mockUserProfileManager.profile = UserProfile(
            name: "Bob",
            profileDescription: "iOS engineer",
            extraInfo: "Lives in Madrid"
        )

        // When
        let result = sut.execute()

        // Then
        XCTAssertTrue(result.contains("Bob"))
        XCTAssertTrue(result.contains("iOS engineer"))
        XCTAssertTrue(result.contains("Madrid"))
    }
}
