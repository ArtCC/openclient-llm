//
//  ModelsViewModelTTSTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 02/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ModelsViewModelTTSTests: XCTestCase {
    // MARK: - Properties

    private var sut: ModelsViewModel!
    private var mockFetchModels: MockFetchModelsUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockFetchModels = MockFetchModelsUseCase()
        mockSettingsManager = MockSettingsManager()
        sut = ModelsViewModel(
            fetchModelsUseCase: mockFetchModels,
            settingsManager: mockSettingsManager
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockFetchModels = nil
        mockSettingsManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — ttsModelTapped

    func test_send_ttsModelTapped_updatesSelectedTTSModelId() async throws {
        // Given
        let ttsModel = LLMModel(id: "tts-1", mode: .audioSpeech)
        mockFetchModels.result = .success([LLMModel(id: "gpt-4"), ttsModel])

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.ttsModelTapped(ttsModel))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedTTSModelId, "tts-1")
    }

    func test_send_ttsModelTapped_doesNotAffectChatModelId() async throws {
        // Given
        let chatModel = LLMModel(id: "gpt-4")
        let ttsModel = LLMModel(id: "tts-1", mode: .audioSpeech)
        mockFetchModels.result = .success([chatModel, ttsModel])
        mockSettingsManager.selectedModelId = "gpt-4"

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.ttsModelTapped(ttsModel))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedTTSModelId, "tts-1")
        XCTAssertEqual(loadedState.selectedModelId, "gpt-4")
    }

    func test_send_ttsModelTapped_persistsViaSvettingsManager() async throws {
        // Given
        let ttsModel = LLMModel(id: "tts-2", mode: .audioSpeech)
        mockFetchModels.result = .success([ttsModel])

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.ttsModelTapped(ttsModel))

        // Then
        XCTAssertEqual(mockSettingsManager.selectedTTSModelId, "tts-2")
    }

    func test_send_modelTapped_doesNotAffectTTSModelId() async throws {
        // Given
        let chatModel = LLMModel(id: "gpt-4")
        let ttsModel = LLMModel(id: "tts-1", mode: .audioSpeech)
        mockFetchModels.result = .success([chatModel, ttsModel])
        mockSettingsManager.selectedTTSModelId = "tts-1"

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.modelTapped(chatModel))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedModelId, "gpt-4")
        XCTAssertEqual(loadedState.selectedTTSModelId, "tts-1")
    }

    // MARK: - Tests — voiceSelected

    func test_send_voiceSelected_updatesStateAndPersists() async throws {
        // Given
        let ttsModel = LLMModel(id: "tts-1", mode: .audioSpeech)
        mockFetchModels.result = .success([ttsModel])

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.voiceSelected("nova", forModelId: "tts-1"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedTTSVoices["tts-1"], "nova")
        XCTAssertEqual(mockSettingsManager.ttsVoices["tts-1"], "nova")
    }

    // MARK: - Tests — loaded state population

    func test_viewAppeared_populatesSelectedTTSModelIdFromSettings() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "tts-1", mode: .audioSpeech)])
        mockSettingsManager.selectedTTSModelId = "tts-1"

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedTTSModelId, "tts-1")
    }

    func test_viewAppeared_populatesTTSVoicesFromSettings() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "tts-1", mode: .audioSpeech)])
        mockSettingsManager.ttsVoices["tts-1"] = "shimmer"

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedTTSVoices["tts-1"], "shimmer")
    }
}
