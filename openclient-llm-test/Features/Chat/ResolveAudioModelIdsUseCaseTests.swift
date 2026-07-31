//
//  ResolveAudioModelIdsUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ResolveAudioModelIdsUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: ResolveAudioModelIdsUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = ResolveAudioModelIdsUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — TTS model resolution

    func test_execute_withSavedTTSModelId_inList_returnsSavedTTSId() {
        // Given
        let ttsModel = LLMModel(id: "tts-1", mode: .audioSpeech)
        mockSettingsManager.selectedTTSModelId = "tts-1"

        // When
        let result = sut.execute(from: [ttsModel])

        // Then
        XCTAssertEqual(result.ttsModelId, "tts-1")
    }

    func test_execute_withSavedTTSModelId_notInList_returnsFirstTTSSpeech() {
        // Given
        let otherTTSModel = LLMModel(id: "tts-other", mode: .audioSpeech)
        mockSettingsManager.selectedTTSModelId = "tts-missing"

        // When
        let result = sut.execute(from: [otherTTSModel])

        // Then
        XCTAssertEqual(result.ttsModelId, "tts-other")
    }

    func test_execute_noTTSSpeechModels_returnsNilTTS() {
        // Given
        let chatModel = LLMModel(id: "gpt-4", mode: .chat)

        // When
        let result = sut.execute(from: [chatModel])

        // Then
        XCTAssertNil(result.ttsModelId)
    }

    // MARK: - Tests — STT model resolution

    func test_execute_withSavedSTTModelId_inList_returnsSavedSTTId() {
        // Given
        let sttModel = LLMModel(id: "whisper-1", mode: .audioTranscription)
        mockSettingsManager.selectedSTTModelId = "whisper-1"

        // When
        let result = sut.execute(from: [sttModel])

        // Then
        XCTAssertEqual(result.transcriptionModelId, "whisper-1")
    }

    func test_execute_withSavedSTTModelId_notInList_fallsBackToApple() {
        // Given
        let chatModel = LLMModel(id: "gpt-4", mode: .chat)
        mockSettingsManager.selectedSTTModelId = "whisper-missing"

        // When
        let result = sut.execute(from: [chatModel])

        // Then
        XCTAssertEqual(result.transcriptionModelId, LLMModel.appleSpeechRecognition.id)
    }

    func test_execute_noSavedSTT_fallsBackToApple() {
        // Given
        let chatModel = LLMModel(id: "gpt-4", mode: .chat)
        mockSettingsManager.selectedSTTModelId = nil

        // When
        let result = sut.execute(from: [chatModel])

        // Then
        XCTAssertEqual(result.transcriptionModelId, LLMModel.appleSpeechRecognition.id)
    }

    func test_execute_savedSTTIsApple_returnsApple() {
        // Given
        mockSettingsManager.selectedSTTModelId = LLMModel.appleSpeechRecognition.id

        // When
        let result = sut.execute(from: [])

        // Then
        XCTAssertEqual(result.transcriptionModelId, LLMModel.appleSpeechRecognition.id)
    }
}
