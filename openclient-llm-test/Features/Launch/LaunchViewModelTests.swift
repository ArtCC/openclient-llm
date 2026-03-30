//
//  LaunchViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//

import XCTest
@testable import openclient_llm

@MainActor
final class LaunchViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: LaunchViewModel!
    private var mockUseCase: MockCheckOnboardingUseCase!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        mockUseCase = MockCheckOnboardingUseCase()
        sut = LaunchViewModel(checkOnboardingUseCase: mockUseCase)
    }

    override func tearDown() {
        sut = nil
        mockUseCase = nil

        super.tearDown()
    }

    // MARK: - Tests

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    func test_send_viewAppeared_onboardingNotCompleted_setsOnboardingState() {
        // Given
        mockUseCase.result = false

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(sut.state, .onboarding)
    }

    func test_send_viewAppeared_onboardingCompleted_setsHomeState() {
        // Given
        mockUseCase.result = true

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(sut.state, .home)
    }

    func test_send_onboardingCompleted_setsHomeState() {
        // Given
        sut = LaunchViewModel(state: .onboarding, checkOnboardingUseCase: mockUseCase)

        // When
        sut.send(.onboardingCompleted)

        // Then
        XCTAssertEqual(sut.state, .home)
    }
}
