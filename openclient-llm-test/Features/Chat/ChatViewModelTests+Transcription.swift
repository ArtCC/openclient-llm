//
//  ChatViewModelTests+Transcription.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Audio Recording

@MainActor
extension ChatViewModelTests {
    func test_send_startRecordingTapped_setsIsRecording() async throws {
        // Given
        let mockRecorder = MockAudioRecorderManager()
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters,
            audioRecorderManager: mockRecorder
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.startRecordingTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isRecording)
        XCTAssertTrue(mockRecorder.startRecordingCalled)
    }

    func test_send_cancelRecordingTapped_clearsRecording() async throws {
        // Given
        let mockRecorder = MockAudioRecorderManager()
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters,
            audioRecorderManager: mockRecorder
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.startRecordingTapped)

        // When
        sut.send(.cancelRecordingTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isRecording)
        XCTAssertTrue(mockRecorder.cancelRecordingCalled)
    }

    func test_send_stopRecordingTapped_triggersTranscription() async throws {
        // Given
        let mockRecorder = MockAudioRecorderManager()
        mockRecorder.stopRecordingResult = (Data([1, 2, 3]), 2.0)

        let mockTranscribe = MockTranscribeAudioUseCase()
        mockTranscribe.result = .success("Hello world")
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "whisper-1", mode: .audioTranscription)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            transcribeAudioUseCase: mockTranscribe,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters,
            audioRecorderManager: mockRecorder
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.startRecordingTapped)

        // When
        sut.send(.stopRecordingTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        XCTAssertTrue(mockRecorder.stopRecordingCalled)
        XCTAssertTrue(mockTranscribe.executeCalled)
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isRecording)
        XCTAssertEqual(loadedState.inputText, "Hello world")
    }

    func test_send_stopRecordingTapped_withNoData_doesNotTranscribe() async throws {
        // Given
        let mockRecorder = MockAudioRecorderManager()
        mockRecorder.stopRecordingResult = (nil, 0)

        let mockTranscribe = MockTranscribeAudioUseCase()
        mockTranscribe.result = .success("Hello world")
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            transcribeAudioUseCase: mockTranscribe,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters,
            audioRecorderManager: mockRecorder
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.stopRecordingTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        XCTAssertFalse(mockTranscribe.executeCalled)
    }

    func test_send_stopRecordingTapped_withError_setsErrorMessage() async throws {
        // Given
        let mockRecorder = MockAudioRecorderManager()
        mockRecorder.stopRecordingResult = (Data([1, 2, 3]), 2.0)

        let mockTranscribe = MockTranscribeAudioUseCase()
        mockTranscribe.result = .failure(APIError.serverUnreachable)
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "whisper-1", mode: .audioTranscription)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            transcribeAudioUseCase: mockTranscribe,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters,
            audioRecorderManager: mockRecorder
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.startRecordingTapped)

        // When
        sut.send(.stopRecordingTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isTranscribing)
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertEqual(loadedState.inputText, "")
    }

    func test_noLiteLLMSTTModels_transcriptionModelIdIsApple() async throws {
        // Given — solo modelos de chat, ningún Whisper de LiteLLM
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then — el micrófono siempre aparece gracias a Apple STT
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.transcriptionModelId, LLMModel.appleSpeechRecognition.id)
    }
}
