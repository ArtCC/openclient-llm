//
//  SettingsManagerSTTTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 02/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SettingsManagerSTTTests: XCTestCase {
    // MARK: - Properties

    private var sut: SettingsManager!
    private var mockKeychain: MockKeychainManager!
    private let suiteName = "com.artcc.openclient-llm.test.stt"

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        UserDefaults().removePersistentDomain(forName: suiteName)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test UserDefaults")
            return
        }
        mockKeychain = MockKeychainManager()
        sut = SettingsManager(defaults: defaults, keychainManager: mockKeychain)
    }

    override func tearDown() async throws {
        UserDefaults().removePersistentDomain(forName: suiteName)
        sut = nil
        mockKeychain = nil

        try await super.tearDown()
    }

    // MARK: - Tests — selectedSTTModelId

    func test_getSelectedSTTModelId_defaultIsNil() {
        XCTAssertNil(sut.getSelectedSTTModelId())
    }

    func test_setSelectedSTTModelId_persistsValue() {
        // When
        sut.setSelectedSTTModelId("whisper-1")

        // Then
        XCTAssertEqual(sut.getSelectedSTTModelId(), "whisper-1")
    }

    func test_setSelectedSTTModelId_nil_clearsValue() {
        // Given
        sut.setSelectedSTTModelId("whisper-1")

        // When
        sut.setSelectedSTTModelId(nil)

        // Then
        XCTAssertNil(sut.getSelectedSTTModelId())
    }
}
