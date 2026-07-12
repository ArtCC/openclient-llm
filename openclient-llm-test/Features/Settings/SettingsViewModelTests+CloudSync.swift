//
//  SettingsViewModelTests+CloudSync.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
extension SettingsViewModelTests {
    func test_send_syncConversationsTapped_updatesSyncResult() {
        // Given
        mockSettingsManager.isCloudSyncEnabled = true
        mockSyncConversations.result = .pendingDownload
        sut.send(.viewAppeared)

        // When
        sut.send(.syncConversationsTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.conversationSyncResult, .pendingDownload)
    }
}
