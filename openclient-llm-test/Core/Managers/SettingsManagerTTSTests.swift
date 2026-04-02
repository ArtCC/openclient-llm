//
//  SettingsManagerTTSTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 02/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SettingsManagerTTSTests: XCTestCase {
    // MARK: - Properties

    private var sut: SettingsManager!
    private var mockKeychain: MockKeychainManager!
    private let suiteName = "com.artcc.openclient-llm.test.tts"

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

    // MARK: - Tests — selectedTTSModelId

    func test_getSelectedTTSModelId_defaultIsNil() {
        XCTAssertNil(sut.getSelectedTTSModelId())
    }

    func test_setSelectedTTSModelId_persistsValue() {
        // When
        sut.setSelectedTTSModelId("tts-1")

        // Then
        XCTAssertEqual(sut.getSelectedTTSModelId(), "tts-1")
    }

    func test_setSelectedTTSModelId_nil_clearsValue() {
        // Given
        sut.setSelectedTTSModelId("tts-1")

        // When
        sut.setSelectedTTSModelId(nil)

        // Then
        XCTAssertNil(sut.getSelectedTTSModelId())
    }

    // MARK: - Tests — selectedTTSVoice

    func test_getSelectedTTSVoice_defaultIsAlloy() {
        XCTAssertEqual(sut.getSelectedTTSVoice(forModelId: "tts-1"), TTSVoice.alloy.rawValue)
    }

    func test_setSelectedTTSVoice_persistsValue() {
        // When
        sut.setSelectedTTSVoice("nova", forModelId: "tts-1")

        // Then
        XCTAssertEqual(sut.getSelectedTTSVoice(forModelId: "tts-1"), "nova")
    }

    func test_getSelectedTTSVoice_differentModelsAreIndependent() {
        // When
        sut.setSelectedTTSVoice("nova", forModelId: "tts-1")
        sut.setSelectedTTSVoice("echo", forModelId: "tts-2")

        // Then
        XCTAssertEqual(sut.getSelectedTTSVoice(forModelId: "tts-1"), "nova")
        XCTAssertEqual(sut.getSelectedTTSVoice(forModelId: "tts-2"), "echo")
    }

    func test_setSelectedTTSVoice_customVoiceId_persists() {
        // When
        sut.setSelectedTTSVoice("eleven_labs_voice_xyz", forModelId: "tts-el")

        // Then
        XCTAssertEqual(sut.getSelectedTTSVoice(forModelId: "tts-el"), "eleven_labs_voice_xyz")
    }

    // MARK: - Tests — deleteAll

    func test_deleteAll_clearsTTSModelId() {
        // Given
        sut.setSelectedTTSModelId("tts-1")

        // When
        sut.deleteAll()

        // Then
        XCTAssertNil(sut.getSelectedTTSModelId())
    }
}
