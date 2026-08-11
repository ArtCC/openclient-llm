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

    var sut: SettingsViewModel!
    private var mockSaveServerConfig: MockSaveServerConfigurationUseCase!
    private var mockTestConnection: MockTestServerConnectionUseCase!
    private var mockCheckLiteLLMHealth: MockCheckLiteLLMHealthUseCase!
    var mockSettingsManager: MockSettingsManager!
    var mockCloudSyncManager: MockCloudSyncManager!
    var mockUserProfileManager: MockUserProfileManager!
    private var mockResetUseCase: MockResetAppDataUseCase!
    var mockFetchSearchTools: MockFetchSearchToolsUseCase!
    var mockSynchronizeAppData: MockSynchronizeAppDataUseCase!
    var mockEnableCloudSync: MockEnableCloudSyncUseCase!
    var cloudSyncRuntimeStore: CloudSyncRuntimeStore!
    var mockCloudAccountAssociation: MockCloudAccountAssociation!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSaveServerConfig = MockSaveServerConfigurationUseCase()
        mockTestConnection = MockTestServerConnectionUseCase()
        mockCheckLiteLLMHealth = MockCheckLiteLLMHealthUseCase()
        mockSettingsManager = MockSettingsManager()
        mockCloudSyncManager = MockCloudSyncManager()
        mockUserProfileManager = MockUserProfileManager()
        mockResetUseCase = MockResetAppDataUseCase()
        mockFetchSearchTools = MockFetchSearchToolsUseCase()
        mockSynchronizeAppData = MockSynchronizeAppDataUseCase()
        mockEnableCloudSync = MockEnableCloudSyncUseCase()
        cloudSyncRuntimeStore = CloudSyncRuntimeStore()
        mockCloudAccountAssociation = MockCloudAccountAssociation()
        sut = SettingsViewModel(
            saveServerConfigurationUseCase: mockSaveServerConfig,
            testServerConnectionUseCase: mockTestConnection,
            checkLiteLLMHealthUseCase: mockCheckLiteLLMHealth,
            fetchSearchToolsUseCase: mockFetchSearchTools,
            settingsManager: mockSettingsManager,
            cloudSyncManager: mockCloudSyncManager,
            synchronizeAppDataUseCase: mockSynchronizeAppData,
            cloudSyncCoordinator: mockEnableCloudSync,
            userProfileManager: mockUserProfileManager,
            cloudSyncRuntimeStore: cloudSyncRuntimeStore,
            cloudAccountAssociation: mockCloudAccountAssociation,
            resetAppUseCase: mockResetUseCase
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockSaveServerConfig = nil
        mockTestConnection = nil
        mockCheckLiteLLMHealth = nil
        mockSettingsManager = nil
        mockCloudSyncManager = nil
        mockUserProfileManager = nil
        mockResetUseCase = nil
        mockFetchSearchTools = nil
        mockSynchronizeAppData = nil
        mockEnableCloudSync = nil
        cloudSyncRuntimeStore = nil
        mockCloudAccountAssociation = nil

        try await super.tearDown()
    }
}

// MARK: - Tests

extension SettingsViewModelTests {
    // MARK: - Init

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

    func test_send_viewAppeared_cloudSyncEnabled_setsCheckingWithoutStartingCoordinator() {
        // Given
        mockSettingsManager.isCloudSyncEnabled = true

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(cloudSyncRuntimeStore.status, .checkingAvailability)
        XCTAssertEqual(mockEnableCloudSync.startCallCount, 0)
        XCTAssertEqual(mockCloudSyncManager.checkCloudAvailabilityCallCount, 0)
    }

    func test_send_viewAppeared_cloudSyncDisabled_keepsRuntimeDisabled() {
        // Given
        mockSettingsManager.isCloudSyncEnabled = false

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(cloudSyncRuntimeStore.status, .disabled)
        XCTAssertEqual(mockEnableCloudSync.startCallCount, 0)
    }

    // MARK: - Tests — showTokenUsageToggled

    func test_send_showTokenUsageToggled_false_disablesTokenUsage() {
        // Given
        mockSettingsManager.showTokenUsage = true
        sut.send(.viewAppeared)

        // When
        sut.send(.showTokenUsageToggled(false))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.showTokenUsage)
        XCTAssertFalse(mockSettingsManager.showTokenUsage)
    }

    func test_send_showTokenUsageToggled_true_enablesTokenUsage() {
        // Given
        mockSettingsManager.showTokenUsage = false
        sut.send(.viewAppeared)

        // When
        sut.send(.showTokenUsageToggled(true))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.showTokenUsage)
        XCTAssertTrue(mockSettingsManager.showTokenUsage)
    }

    func test_send_viewAppeared_loadsShowTokenUsageFromManager() {
        // Given
        mockSettingsManager.showTokenUsage = false

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.showTokenUsage)
    }
}

// MARK: - Cloud Conflict Tests

extension SettingsViewModelTests {
    func test_send_cloudSyncToggled_true_showsConflictAlert_whenBothHaveData() async {
        // Given
        mockEnableCloudSync.result = .success(.profileConflict)
        mockUserProfileManager.localProfile = UserProfile(name: "Local", profileDescription: "", extraInfo: "")
        mockUserProfileManager.cloudProfile = UserProfile(name: "Cloud", profileDescription: "", extraInfo: "")
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.showCloudSyncConflictAlert
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.showCloudSyncConflictAlert)
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
    }

    func test_send_cloudSyncToggled_true_enablesDirectly_whenNoConflict() async {
        // Given
        mockUserProfileManager.localProfile = UserProfile(name: "Local", profileDescription: "", extraInfo: "")
        mockUserProfileManager.cloudProfile = nil
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockEnableCloudSync.startCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.showCloudSyncConflictAlert)
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
        XCTAssertTrue(mockSettingsManager.isCloudSyncEnabled)
    }

    func test_send_cloudSyncToggled_true_pushesLocalToCloud_whenCloudEmpty() async {
        // Given
        mockUserProfileManager.localProfile = UserProfile(name: "Local", profileDescription: "", extraInfo: "")
        mockUserProfileManager.cloudProfile = nil
        sut.send(.viewAppeared)

        // When
        sut.send(.cloudSyncToggled(true))
        await waitUntil { self.mockEnableCloudSync.startCallCount == 1 }

        // Then
        XCTAssertNil(mockUserProfileManager.resolvedKeepLocal)
    }

    func test_send_cloudSyncConflictResolved_keepLocal_enablesSyncAndResolvesConflict() async {
        // Given
        mockEnableCloudSync.result = .success(.profileConflict)
        mockUserProfileManager.localProfile = UserProfile(name: "Local", profileDescription: "", extraInfo: "")
        mockUserProfileManager.cloudProfile = UserProfile(name: "Cloud", profileDescription: "", extraInfo: "")
        sut.send(.viewAppeared)
        sut.send(.cloudSyncToggled(true))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.showCloudSyncConflictAlert
        }

        // When
        sut.send(.cloudSyncConflictResolved(keepLocal: true))
        await waitUntil { self.mockUserProfileManager.resolvedKeepLocal == true }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
        XCTAssertFalse(loadedState.showCloudSyncConflictAlert)
        XCTAssertTrue(mockSettingsManager.isCloudSyncEnabled)
        XCTAssertEqual(mockUserProfileManager.resolvedKeepLocal, true)
    }

    func test_send_cloudSyncConflictResolved_keepCloud_enablesSyncAndResolvesConflict() async {
        // Given
        mockEnableCloudSync.result = .success(.profileConflict)
        mockUserProfileManager.localProfile = UserProfile(name: "Local", profileDescription: "", extraInfo: "")
        mockUserProfileManager.cloudProfile = UserProfile(name: "Cloud", profileDescription: "", extraInfo: "")
        sut.send(.viewAppeared)
        sut.send(.cloudSyncToggled(true))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.showCloudSyncConflictAlert
        }

        // When
        sut.send(.cloudSyncConflictResolved(keepLocal: false))
        await waitUntil { self.mockUserProfileManager.resolvedKeepLocal == false }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
        XCTAssertFalse(loadedState.showCloudSyncConflictAlert)
        XCTAssertEqual(mockUserProfileManager.resolvedKeepLocal, false)
    }

    func test_send_cloudSyncConflictCancelled_dismissesAlertAndRetainsIntent() async {
        // Given
        mockEnableCloudSync.result = .success(.profileConflict)
        mockUserProfileManager.localProfile = UserProfile(name: "Local", profileDescription: "", extraInfo: "")
        mockUserProfileManager.cloudProfile = UserProfile(name: "Cloud", profileDescription: "", extraInfo: "")
        sut.send(.viewAppeared)
        sut.send(.cloudSyncToggled(true))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.showCloudSyncConflictAlert
        }

        // When
        sut.send(.cloudSyncConflictCancelled)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.showCloudSyncConflictAlert)
        XCTAssertTrue(loadedState.isCloudSyncEnabled)
    }

    // MARK: - Tests — resetConfirmed

    func test_send_resetConfirmed_executesReset() async {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.resetConfirmed)
        await waitUntil { self.mockResetUseCase.executeCalled }

        // Then
        XCTAssertTrue(mockResetUseCase.executeCalled)
    }

    func test_send_resetConfirmed_reloadsSettingsFromManager() async {
        // Given
        mockSettingsManager.serverBaseURL = "https://example.com"
        sut.send(.viewAppeared)
        // Simulate that after reset the manager returns a different non-empty URL.
        // Using a non-empty value avoids the #if DEBUG fallback to Constants.URLs.serverUrl.
        mockSettingsManager.serverBaseURL = "https://after-reset.local"

        // When
        sut.send(.resetConfirmed)
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.serverURL == "https://after-reset.local"
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.serverURL, "https://after-reset.local")
    }

    func test_send_resetConfirmed_failure_retainsVisibleError() async {
        // Given
        mockResetUseCase.executeError = NSError(domain: "SettingsViewModelTests", code: 1)
        sut.send(.viewAppeared)

        // When
        sut.send(.resetConfirmed)
        await waitUntil {
            guard case .loaded(let loadedState) = self.sut.state else { return false }
            return loadedState.resetErrorMessage != nil
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else { return XCTFail("Expected loaded state") }
        XCTAssertNotNil(loadedState.resetErrorMessage)
    }

}
