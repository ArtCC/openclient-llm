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

    // MARK: - Tests — nameChanged

    func test_send_nameChanged_updatesName() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.nameChanged("Alice"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.name, "Alice")
    }

    func test_send_nameChanged_truncatesAt50Chars() {
        // Given
        sut.send(.viewAppeared)
        let longName = String(repeating: "A", count: 60)

        // When
        sut.send(.nameChanged(longName))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.name.count, 50)
    }

    // MARK: - Tests — descriptionChanged

    func test_send_descriptionChanged_truncatesAt200Chars() {
        // Given
        sut.send(.viewAppeared)
        let longDesc = String(repeating: "B", count: 250)

        // When
        sut.send(.descriptionChanged(longDesc))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.profileDescription.count, 200)
    }

    // MARK: - Tests — extraInfoChanged

    func test_send_extraInfoChanged_truncatesAt500Chars() {
        // Given
        sut.send(.viewAppeared)
        let longInfo = String(repeating: "C", count: 600)

        // When
        sut.send(.extraInfoChanged(longInfo))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.extraInfo.count, 500)
    }

    // MARK: - Tests — saveTapped

    func test_send_saveTapped_persistsProfile() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.nameChanged("Bob"))
        sut.send(.descriptionChanged("Engineer"))
        sut.send(.extraInfoChanged("Swift enthusiast"))

        // When
        sut.send(.saveTapped)

        // Then
        XCTAssertEqual(mockUserProfileManager.savedProfile?.name, "Bob")
        XCTAssertEqual(mockUserProfileManager.savedProfile?.profileDescription, "Engineer")
        XCTAssertEqual(mockUserProfileManager.savedProfile?.extraInfo, "Swift enthusiast")
    }

    func test_send_saveTapped_resetsHasChanges() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.nameChanged("NewName"))
        XCTAssertTrue(sut.hasChanges)

        // When
        sut.send(.saveTapped)

        // Then
        XCTAssertFalse(sut.hasChanges)
    }

    // MARK: - Tests — hasChanges

    func test_hasChanges_falseAfterLoad() {
        // Given
        mockUserProfileManager.profile = UserProfile(name: "Arturo", profileDescription: "", extraInfo: "")

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertFalse(sut.hasChanges)
    }

    func test_hasChanges_trueAfterNameEdit() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.nameChanged("Changed"))

        // Then
        XCTAssertTrue(sut.hasChanges)
    }
}
