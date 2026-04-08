//
//  OnboardingViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: OnboardingViewModel!
    private var mockCompleteOnboarding: MockCompleteOnboardingUseCase!
    private var mockSaveServerConfig: MockSaveServerConfigurationUseCase!
    private var mockTestConnection: MockTestServerConnectionUseCase!
    private var mockCheckLiteLLMHealth: MockCheckLiteLLMHealthUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockCompleteOnboarding = MockCompleteOnboardingUseCase()
        mockSaveServerConfig = MockSaveServerConfigurationUseCase()
        mockTestConnection = MockTestServerConnectionUseCase()
        mockCheckLiteLLMHealth = MockCheckLiteLLMHealthUseCase()
        sut = OnboardingViewModel(
            completeOnboardingUseCase: mockCompleteOnboarding,
            saveServerConfigurationUseCase: mockSaveServerConfig,
            testServerConnectionUseCase: mockTestConnection,
            checkLiteLLMHealthUseCase: mockCheckLiteLLMHealth
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockCompleteOnboarding = nil
        mockSaveServerConfig = nil
        mockTestConnection = nil
        mockCheckLiteLLMHealth = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_setsLoadedState() {
        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(sut.state, .loaded(.init()))
    }

    func test_send_viewAppeared_currentStep_isWelcome() {
        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.currentStep, .welcome)
    }

    // MARK: - Tests — getStartedTapped

    func test_send_getStartedTapped_movesToServerConfiguration() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.getStartedTapped)

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.currentStep, .serverConfiguration)
    }

    // MARK: - Tests — backTapped

    func test_send_backTapped_fromWelcome_staysOnWelcome() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.backTapped)

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.currentStep, .welcome)
    }

    func test_send_backTapped_fromServerConfiguration_movesToWelcome() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.getStartedTapped)

        // When
        sut.send(.backTapped)

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.currentStep, .welcome)
    }

    func test_send_backTapped_fromAllSet_movesToServerConfiguration() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.getStartedTapped)
        sut.send(.nextTapped)

        // When
        sut.send(.backTapped)

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.currentStep, .serverConfiguration)
    }

    // MARK: - Tests — skipTapped

    func test_send_skipTapped_completesOnboarding() {
        // Given
        sut.send(.viewAppeared)
        var onCompleteCalled = false
        sut.onComplete = { onCompleteCalled = true }

        // When
        sut.send(.skipTapped)

        // Then
        XCTAssertTrue(mockCompleteOnboarding.executeCalled)
        XCTAssertTrue(onCompleteCalled)
    }

    func test_send_skipTapped_doesNotSaveServerConfiguration() {
        // Given
        sut.send(.viewAppeared)
        sut.onComplete = {}

        // When
        sut.send(.skipTapped)

        // Then
        XCTAssertNil(mockSaveServerConfig.savedServerURL)
        XCTAssertNil(mockSaveServerConfig.savedAPIKey)
    }

    // MARK: - Tests — serverURLChanged

    func test_send_serverURLChanged_updatesState() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.serverURLChanged("https://example.com"))

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.serverURL, "https://example.com")
    }

    func test_send_serverURLChanged_resetsConnectionStatus() {
        // Given
        sut = OnboardingViewModel(
            state: .loaded(.init(connectionStatus: .success)),
            completeOnboardingUseCase: mockCompleteOnboarding,
            saveServerConfigurationUseCase: mockSaveServerConfig,
            testServerConnectionUseCase: mockTestConnection
        )

        // When
        sut.send(.serverURLChanged("https://new-url.com"))

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.connectionStatus, .idle)
    }

    // MARK: - Tests — apiKeyChanged

    func test_send_apiKeyChanged_updatesState() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.apiKeyChanged("test-key"))

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.apiKey, "test-key")
    }

    func test_send_apiKeyChanged_resetsConnectionStatus() {
        // Given
        sut = OnboardingViewModel(
            state: .loaded(.init(connectionStatus: .success)),
            completeOnboardingUseCase: mockCompleteOnboarding,
            saveServerConfigurationUseCase: mockSaveServerConfig,
            testServerConnectionUseCase: mockTestConnection
        )

        // When
        sut.send(.apiKeyChanged("new-key"))

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.connectionStatus, .idle)
    }

    // MARK: - Tests — testConnectionTapped

    func test_send_testConnectionTapped_setsTestingStatus() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.serverURLChanged("https://example.com"))

        // When
        sut.send(.testConnectionTapped)

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.connectionStatus, .testing)
    }

    func test_send_testConnectionTapped_success_setsSuccessStatus() async throws {
        // Given
        sut.send(.viewAppeared)
        sut.send(.serverURLChanged("https://example.com"))
        mockTestConnection.result = .success(())

        // When
        sut.send(.testConnectionTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.connectionStatus, .success)
    }

    func test_send_testConnectionTapped_failure_setsFailureStatus() async throws {
        // Given
        sut.send(.viewAppeared)
        sut.send(.serverURLChanged("https://example.com"))
        mockTestConnection.result = .failure(OnboardingRepositoryError.serverUnreachable)

        // When
        sut.send(.testConnectionTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        if case .failure = loaded.connectionStatus {
            // Expected failure status
        } else {
            XCTFail("Expected failure connection status")
        }
    }

    // MARK: - Tests — nextTapped

    func test_send_nextTapped_movesToAllSet() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.getStartedTapped)

        // When
        sut.send(.nextTapped)

        // Then
        guard case .loaded(let loaded) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loaded.currentStep, .allSet)
    }

    // MARK: - Tests — startChattingTapped

    func test_send_startChattingTapped_savesServerConfiguration() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.serverURLChanged("https://example.com"))
        sut.send(.apiKeyChanged("test-key"))
        sut.onComplete = {}

        // When
        sut.send(.startChattingTapped)

        // Then
        XCTAssertEqual(mockSaveServerConfig.savedServerURL, "https://example.com")
        XCTAssertEqual(mockSaveServerConfig.savedAPIKey, "test-key")
    }

    func test_send_startChattingTapped_completesOnboarding() {
        // Given
        sut.send(.viewAppeared)
        var onCompleteCalled = false
        sut.onComplete = { onCompleteCalled = true }

        // When
        sut.send(.startChattingTapped)

        // Then
        XCTAssertTrue(mockCompleteOnboarding.executeCalled)
        XCTAssertTrue(onCompleteCalled)
    }
}
