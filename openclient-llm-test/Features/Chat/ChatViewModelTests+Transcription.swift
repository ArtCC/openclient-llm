//
//  ChatViewModelTests+Transcription.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Audio Transcription

@MainActor
extension ChatViewModelTests {
    func test_send_viewAppeared_detectsTranscriptionModel() async throws {
        // Given
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "whisper-1", mode: .audioTranscription)
        ])

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.transcriptionModel?.id, "whisper-1")
        XCTAssertEqual(loadedState.availableModels.count, 1, "Should not include the transcription model")
    }

    func test_send_audioRecorded_setsIsTranscribing() async throws {
        // Given
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
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.audioRecorded(Data([1, 2, 3]), 2.0))

        // Then — isTranscribing is set synchronously before the async Task runs
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isTranscribing)
    }

    func test_send_audioRecorded_callsTranscribeUseCase() async throws {
        // Given
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
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.audioRecorded(Data([1, 2, 3]), 2.0))
        try await Task.sleep(for: .milliseconds(200))

        // Then
        XCTAssertTrue(mockTranscribe.executeCalled)
    }

    func test_send_audioRecorded_setsInputText() async throws {
        // Given
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
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.audioRecorded(Data([1, 2, 3]), 2.0))
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.inputText, "Hello world")
        XCTAssertFalse(loadedState.isTranscribing)
    }

    func test_send_audioRecorded_withError_setsErrorMessage() async throws {
        // Given
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
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.audioRecorded(Data([1, 2, 3]), 2.0))
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

    func test_send_audioRecorded_withoutTranscriptionModel_showsError() async throws {
        // Given
        let mockTranscribe = MockTranscribeAudioUseCase()
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            transcribeAudioUseCase: mockTranscribe,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.audioRecorded(Data([1, 2, 3]), 2.0))
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(mockTranscribe.executeCalled)
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertFalse(loadedState.isTranscribing)
    }
}
