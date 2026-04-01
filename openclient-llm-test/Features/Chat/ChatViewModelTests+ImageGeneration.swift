//
//  ChatViewModelTests+ImageGeneration.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests — Image Generation

@MainActor
extension ChatViewModelTests {
    func test_send_viewAppeared_detectsImageModel() async throws {
        // Given
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "dall-e-3", mode: .imageGeneration)
        ])

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.imageModel?.id, "dall-e-3")
        XCTAssertEqual(loadedState.availableModels.count, 1, "Image model should not be in chat availableModels")
    }

    func test_send_generateImageTapped_setsIsGeneratingImage() async throws {
        // Given
        let mockGenerateImage = MockGenerateImageUseCase()
        let generatedImage = GeneratedImage(prompt: "A cat", imageData: Data([1, 2, 3]), modelId: "dall-e-3")
        mockGenerateImage.result = .success(generatedImage)
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "dall-e-3", mode: .imageGeneration)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            generateImageUseCase: mockGenerateImage,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.inputChanged("A cat in space"))

        // When
        sut.send(.generateImageTapped)

        // Then — synchronous check before task completes
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.isGeneratingImage)
    }

    func test_send_generateImageTapped_callsGenerateImageUseCase() async throws {
        // Given
        let mockGenerateImage = MockGenerateImageUseCase()
        let generatedImage = GeneratedImage(prompt: "A cat", imageData: Data([1, 2, 3]), modelId: "dall-e-3")
        mockGenerateImage.result = .success(generatedImage)
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "dall-e-3", mode: .imageGeneration)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            generateImageUseCase: mockGenerateImage,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.inputChanged("A cat in space"))

        // When
        sut.send(.generateImageTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        XCTAssertTrue(mockGenerateImage.executeCalled)
    }

    func test_send_generateImageTapped_appendsAssistantMessageWithAttachment() async throws {
        // Given
        let imageData = Data([1, 2, 3, 4])
        let mockGenerateImage = MockGenerateImageUseCase()
        mockGenerateImage.result = .success(GeneratedImage(prompt: "A cat", imageData: imageData, modelId: "dall-e-3"))
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "dall-e-3", mode: .imageGeneration)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            generateImageUseCase: mockGenerateImage,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.inputChanged("A cat in space"))

        // When
        sut.send(.generateImageTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.count, 2)
        let assistantMessage = loadedState.messages.last
        XCTAssertEqual(assistantMessage?.role, .assistant)
        XCTAssertEqual(assistantMessage?.attachments.first?.type, .image)
        XCTAssertEqual(assistantMessage?.attachments.first?.data, imageData)
        XCTAssertFalse(loadedState.isGeneratingImage)
        XCTAssertTrue(loadedState.inputText.isEmpty)
    }

    func test_send_generateImageTapped_withError_setsErrorMessage() async throws {
        // Given
        let mockGenerateImage = MockGenerateImageUseCase()
        mockGenerateImage.result = .failure(APIError.serverUnreachable)
        mockFetchModels.result = .success([
            LLMModel(id: "gpt-4"),
            LLMModel(id: "dall-e-3", mode: .imageGeneration)
        ])

        sut = ChatViewModel(
            fetchModelsUseCase: mockFetchModels,
            streamMessageUseCase: mockStreamMessage,
            saveConversationUseCase: mockSaveConversation,
            generateImageUseCase: mockGenerateImage,
            settingsManager: mockSettingsManager,
            conversationStartersManager: mockConversationStarters
        )

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.inputChanged("A cat in space"))

        // When
        sut.send(.generateImageTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isGeneratingImage)
        XCTAssertNotNil(loadedState.errorMessage)
    }

    func test_send_generateImageTapped_withoutImageModel_showsError() async throws {
        // Given — no image generation model available
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])

        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))
        sut.send(.inputChanged("A cat in space"))

        // When
        sut.send(.generateImageTapped)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertFalse(loadedState.isGeneratingImage)
    }
}
