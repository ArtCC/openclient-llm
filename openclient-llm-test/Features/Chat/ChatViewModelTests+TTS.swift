//
//  ChatViewModelTests+TTS.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Text-to-Speech

@MainActor
extension ChatViewModelTests {
    func test_send_speakMessageTapped_callsSynthesizeUseCase() async throws {
        // Given
        let mockSynthesize = MockSynthesizeSpeechUseCase()
        mockSynthesize.result = .success(Data([1, 2, 3]))
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "tts-1", mode: .audioSpeech)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            synthesizeSpeechUseCase: mockSynthesize,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let message = ChatMessage(role: .assistant, content: "Hello there!")

        // When
        sut.send(.speakMessageTapped(message))
        try await Task.sleep(for: .milliseconds(200))

        // Then
        XCTAssertTrue(mockSynthesize.executeCalled)
    }

    func test_send_speakMessageTapped_setsSpeakingState() async throws {
        // Given
        let mockSynthesize = MockSynthesizeSpeechUseCase()
        mockSynthesize.result = .success(Data([1, 2, 3]))
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "tts-1", mode: .audioSpeech)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            synthesizeSpeechUseCase: mockSynthesize,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let message = ChatMessage(role: .assistant, content: "Hello there!")

        // When
        sut.send(.speakMessageTapped(message))

        // Then — while speaking, state should reflect it
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isSpeaking)
        XCTAssertEqual(loadedState.speakingMessageId, message.id)
    }

    func test_send_speakMessageTapped_withEmptyContent_doesNotSpeak() async throws {
        // Given
        let mockSynthesize = MockSynthesizeSpeechUseCase()
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "tts-1", mode: .audioSpeech)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            synthesizeSpeechUseCase: mockSynthesize,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let message = ChatMessage(role: .assistant, content: "")

        // When
        sut.send(.speakMessageTapped(message))
        try await Task.sleep(for: .milliseconds(100))

        // Then
        XCTAssertFalse(mockSynthesize.executeCalled)
    }

    func test_send_speakMessageTapped_withError_setsErrorMessage() async throws {
        // Given
        let mockSynthesize = MockSynthesizeSpeechUseCase()
        mockSynthesize.result = .failure(APIError.serverUnreachable)
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "tts-1", mode: .audioSpeech)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            synthesizeSpeechUseCase: mockSynthesize,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let message = ChatMessage(role: .assistant, content: "Hello")

        // When
        sut.send(.speakMessageTapped(message))
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isSpeaking)
        XCTAssertNil(loadedState.speakingMessageId)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    func test_send_stopSpeakingTapped_resetsSpeakingState() async throws {
        // Given
        let mockSynthesize = MockSynthesizeSpeechUseCase()
        mockSynthesize.result = .success(Data([1, 2, 3]))
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "tts-1", mode: .audioSpeech)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            synthesizeSpeechUseCase: mockSynthesize,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        let message = ChatMessage(role: .assistant, content: "Hello")
        sut.send(.speakMessageTapped(message))
        try await Task.sleep(for: .milliseconds(50))

        // When
        sut.send(.stopSpeakingTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isSpeaking)
        XCTAssertNil(loadedState.speakingMessageId)
    }

}
