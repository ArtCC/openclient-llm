//
//  UserProfileViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class UserProfileViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: UserProfileViewModel!
    private var mockUserProfileManager: MockUserProfileManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockUserProfileManager = MockUserProfileManager()
        sut = UserProfileViewModel(userProfileManager: mockUserProfileManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockUserProfileManager = nil
        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_loadsProfile() {
        // Given
        mockUserProfileManager.profile = UserProfile(
            name: "Arturo",
            profileDescription: "Developer",
            extraInfo: "Loves Swift"
        )

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.name, "Arturo")
        XCTAssertEqual(loadedState.profileDescription, "Developer")
        XCTAssertEqual(loadedState.extraInfo, "Loves Swift")
    }

    func test_send_viewAppeared_setsOriginalValues() {
        // Given
        mockUserProfileManager.profile = UserProfile(
            name: "Arturo",
            profileDescription: "Developer",
            extraInfo: "Loves Swift"
        )

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.originalName, "Arturo")
        XCTAssertEqual(loadedState.originalDescription, "Developer")
        XCTAssertEqual(loadedState.originalExtraInfo, "Loves Swift")
    }

    // MARK: - Tests — save

    func test_send_save_persistsProfile() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.save(name: "Bob", description: "Engineer", extraInfo: "Swift enthusiast"))

        // Then
        XCTAssertEqual(mockUserProfileManager.savedProfile?.name, "Bob")
        XCTAssertEqual(mockUserProfileManager.savedProfile?.profileDescription, "Engineer")
        XCTAssertEqual(mockUserProfileManager.savedProfile?.extraInfo, "Swift enthusiast")
    }

    func test_send_save_updatesLoadedState() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.save(name: "Alice", description: "Designer", extraInfo: "Loves colors"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.name, "Alice")
        XCTAssertEqual(loadedState.profileDescription, "Designer")
        XCTAssertEqual(loadedState.extraInfo, "Loves colors")
    }

    func test_send_save_updatesOriginalValues() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.save(name: "Alice", description: "Designer", extraInfo: "Loves colors"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.originalName, "Alice")
        XCTAssertEqual(loadedState.originalDescription, "Designer")
        XCTAssertEqual(loadedState.originalExtraInfo, "Loves colors")
    }
}
