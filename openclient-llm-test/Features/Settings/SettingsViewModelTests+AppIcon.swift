//
//  SettingsViewModelTests+AppIcon.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - App Icon Tests

extension SettingsViewModelTests {
    func test_send_viewAppeared_withAlternateIcon_loadsSelectedIcon() {
        // Given
        mockAppIconManager.selectedIcon = .ocean

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedAppIcon, .ocean)
    }

    func test_send_appIconSelected_success_updatesSelectedIcon() async {
        // Given
        sut.send(.viewAppeared)

        // When
        sut.send(.appIconSelected(.berry))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.selectedAppIcon == .berry
        }

        // Then
        XCTAssertEqual(mockAppIconManager.setIconCalls, [.berry])
    }

    func test_send_appIconSelected_failure_retainsSelectedIconAndShowsError() async {
        // Given
        mockAppIconManager.selectedIcon = .ocean
        mockAppIconManager.setIconResult = .failure(NSError(domain: "AppIconTests", code: 1))
        sut.send(.viewAppeared)

        // When
        sut.send(.appIconSelected(.solar))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.appIconError != nil
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedAppIcon, .ocean)
        XCTAssertFalse(loadedState.isChangingAppIcon)
    }

    func test_send_appIconSelected_currentIcon_doesNotRequestChange() {
        // Given
        mockAppIconManager.selectedIcon = .terminal
        sut.send(.viewAppeared)

        // When
        sut.send(.appIconSelected(.terminal))

        // Then
        XCTAssertTrue(mockAppIconManager.setIconCalls.isEmpty)
    }
}
