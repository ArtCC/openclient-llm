//
//  AudioTranscriptionViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class AudioTranscriptionViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: AudioTranscriptionViewModel!
    private var mockTranscribeAudio: MockTranscribeAudioUseCase!
    private var mockFetchModels: MockFetchModelsUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockTranscribeAudio = MockTranscribeAudioUseCase()
        mockFetchModels = MockFetchModelsUseCase()
        sut = AudioTranscriptionViewModel(
            transcribeAudioUseCase: mockTranscribeAudio,
            fetchModelsUseCase: mockFetchModels
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockTranscribeAudio = nil
        mockFetchModels = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        // Then
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_withModels_setsLoadedState() async throws {
        // Given
        let models = [LLMModel(id: "whisper-1"), LLMModel(id: "whisper-large")]
        mockFetchModels.result = .success(models)

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.availableModels.count, 2)
        XCTAssertEqual(loadedState.selectedModel, "whisper-1")
        XCTAssertTrue(loadedState.transcriptions.isEmpty)
        XCTAssertNil(loadedState.errorMessage)
    }

    func test_send_viewAppeared_withError_setsErrorMessage() async throws {
        // Given
        mockFetchModels.result = .failure(APIError.serverUnreachable)

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.availableModels.isEmpty)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    // MARK: - Tests — modelSelected

    func test_send_modelSelected_updatesModel() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1"), LLMModel(id: "whisper-large")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.modelSelected("whisper-large"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedModel, "whisper-large")
    }

    // MARK: - Tests — languageChanged

    func test_send_languageChanged_updatesLanguage() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.languageChanged("es"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.language, "es")
    }

    // MARK: - Tests — audioRecorded

    func test_send_audioRecorded_setsAudioData() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let audioData = Data([1, 2, 3, 4])

        // When
        sut.send(.audioRecorded(audioData, 5.0))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.audioData, audioData)
        XCTAssertEqual(loadedState.audioFileName, "recording.m4a")
        XCTAssertEqual(loadedState.audioDuration, 5.0)
    }

    // MARK: - Tests — audioFileSelected

    func test_send_audioFileSelected_setsAudioFile() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let audioData = Data([5, 6, 7, 8])

        // When
        sut.send(.audioFileSelected(audioData, "interview.mp3"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.audioData, audioData)
        XCTAssertEqual(loadedState.audioFileName, "interview.mp3")
    }

    // MARK: - Tests — clearTapped

    func test_send_clearTapped_clearsAudioData() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.audioRecorded(Data([1, 2, 3]), 3.0))

        // When
        sut.send(.clearTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNil(loadedState.audioData)
        XCTAssertNil(loadedState.audioFileName)
        XCTAssertEqual(loadedState.audioDuration, 0)
    }

    // MARK: - Tests — transcribeTapped

    func test_send_transcribeTapped_withAudio_transcribesSuccessfully() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1")])
        mockTranscribeAudio.result = .success("Hello, world!")
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.audioRecorded(Data([1, 2, 3]), 2.0))

        // When
        sut.send(.transcribeTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.transcriptions.count, 1)
        XCTAssertEqual(loadedState.transcriptions.first?.text, "Hello, world!")
        XCTAssertFalse(loadedState.isTranscribing)
        XCTAssertNil(loadedState.audioData)
        XCTAssertTrue(mockTranscribeAudio.executeCalled)
    }

    func test_send_transcribeTapped_withoutAudio_doesNotTranscribe() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1")])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.transcribeTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        XCTAssertFalse(mockTranscribeAudio.executeCalled)
    }

    func test_send_transcribeTapped_withError_setsErrorMessage() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "whisper-1")])
        mockTranscribeAudio.result = .failure(APIError.serverUnreachable)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.audioRecorded(Data([1, 2, 3]), 2.0))

        // When
        sut.send(.transcribeTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isTranscribing)
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertTrue(loadedState.transcriptions.isEmpty)
    }
}
