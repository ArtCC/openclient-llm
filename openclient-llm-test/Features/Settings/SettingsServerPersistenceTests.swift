//
//  SettingsServerPersistenceTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SettingsServerPersistenceTests: XCTestCase {
    func test_send_saveTapped_securePersistenceFails_keepsSettingsUnsaved() {
        // Given
        let saveConfiguration = MockSaveServerConfigurationUseCase()
        saveConfiguration.result = false
        let sut = SettingsViewModel(
            state: .loaded(.init(serverURL: "https://example.com", apiKey: "key")),
            saveServerConfigurationUseCase: saveConfiguration,
            fetchSearchToolsUseCase: MockFetchSearchToolsUseCase(),
            fetchMCPToolsUseCase: MockFetchMCPToolsUseCase(),
            settingsManager: MockSettingsManager(),
            cloudSyncManager: MockCloudSyncManager(),
            synchronizeAppDataUseCase: MockSynchronizeAppDataUseCase(),
            cloudSyncCoordinator: MockEnableCloudSyncUseCase(),
            userProfileManager: MockUserProfileManager(),
            cloudSyncRuntimeStore: CloudSyncRuntimeStore(),
            cloudAccountAssociation: MockCloudAccountAssociation()
        )

        // When
        sut.send(.saveTapped)
        sut.send(.saveTapped)

        // Then
        guard case .loaded(let state) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(state.isSaved)
        XCTAssertNotNil(state.serverPersistenceError)
        XCTAssertEqual(state.serverPersistenceFailureCount, 2)
    }
}
