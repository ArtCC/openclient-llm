//
//  SettingsViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SettingsViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: SettingsViewModel!
    private var mockSaveServerConfig: MockSaveServerConfigurationUseCase!
    private var mockTestConnection: MockTestServerConnectionUseCase!
    private var mockSettingsManager: MockSettingsManager!
    private var mockCloudSyncManager: MockCloudSyncManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSaveServerConfig = MockSaveServerConfigurationUseCase()
        mockTestConnection = MockTestServerConnectionUseCase()
        mockSettingsManager = MockSettingsManager()
        mockCloudSyncManager = MockCloudSyncManager()
        sut = SettingsViewModel(
            saveServerConfigurationUseCase: mockSaveServerConfig,
            testServerConnectionUseCase: mockTestConnection,
            settingsManager: mockSettingsManager,
            cloudSyncManager: mockCloudSyncManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockSaveServerConfig = nil
        mockTestConnection = nil
        mockSettingsManager = nil
        mockCloudSyncManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_loadsSettingsFromManager() {
        // Given
        mockSettingsManager.serverBaseURL = "https://example.com"
        mockSettingsManager.apiKey = "test-key"

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.serverURL, "https://example.com")
        XCTAssertEqual(loadedState.apiKey, "test-key")
    }

    // MARK: - Tests — serverURLChanged

    func test_send_serverURLChanged_updatesURL() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.serverURLChanged("https://new-server.com"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.serverURL, "https://new-server.com")
        XCTAssertEqual(loadedState.connectionStatus, .idle)
    }

    // MARK: - Tests — apiKeyChanged

    func test_send_apiKeyChanged_updatesKey() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.apiKeyChanged("new-key"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.apiKey, "new-key")
    }

    // MARK: - Tests — testConnectionTapped

    func test_send_testConnectionTapped_success_setsSuccessStatus() async throws {
        // Given
        sut.send(.viewAppeared)
        sut.send(.serverURLChanged("https://example.com"))
        mockTestConnection.result = .success(())

        // When
        sut.send(.testConnectionTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.connectionStatus, .success)
    }

    func test_send_testConnectionTapped_failure_setsFailureStatus() async throws {
        // Given
        sut.send(.viewAppeared)
        sut.send(.serverURLChanged("https://example.com"))
        mockTestConnection.result = .failure(APIError.serverUnreachable)

        // When
        sut.send(.testConnectionTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        if case .failure = loadedState.connectionStatus {
            // Expected
        } else {
            XCTFail("Expected failure status")
        }
    }

    // MARK: - Tests — saveTapped

    func test_send_saveTapped_savesConfiguration() {
        // Given
        sut.send(.viewAppeared)
        sut.send(.serverURLChanged("https://example.com"))
        sut.send(.apiKeyChanged("my-key"))

        // When
        sut.send(.saveTapped)

        // Then
        XCTAssertEqual(mockSaveServerConfig.savedServerURL, "https://example.com")
        XCTAssertEqual(mockSaveServerConfig.savedAPIKey, "my-key")
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isSaved)
    }

    // MARK: - Tests — cloudSyncToggled

    func test_send_cloudSyncToggled_enablesSync() {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
        XCTAssertTrue(mockSettingsManager.isCloudSyncEnabled)
    }

    func test_send_cloudSyncToggled_disablesSync() {
        // Given
        mockSettingsManager.isCloudSyncEnabled = true
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(false))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isCloudSyncEnabled)
        XCTAssertFalse(mockSettingsManager.isCloudSyncEnabled)
    }

    func test_send_viewAppeared_loadsCloudAvailability() {
        // Given
        mockCloudSyncManager.cloudAvailable = true

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isCloudAvailable)
    }

    func test_send_viewAppeared_cloudNotAvailable() {
        // Given
        mockCloudSyncManager.cloudAvailable = false

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isCloudAvailable)
    }
}
