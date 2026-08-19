//
//  SettingsViewModelTests+RemoteConfig.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 18/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Remote Config Tests

@MainActor
extension SettingsViewModelTests {
    func test_send_viewAppeared_tipJarDisabled_setsTipJarDisabled() {
        // Given
        mockRemoteConfigManager.currentConfig = .stub(isTipJarEnabled: false)

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isTipJarEnabled)
    }

    func test_send_viewAppeared_tipJarMissing_setsTipJarEnabled() {
        // Given
        mockRemoteConfigManager.currentConfig = .stub(isTipJarEnabled: nil)

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isTipJarEnabled)
    }
}
