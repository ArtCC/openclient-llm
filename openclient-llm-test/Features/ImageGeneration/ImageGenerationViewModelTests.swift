//
//  ImageGenerationViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ImageGenerationViewModelTests: XCTestCase {
    // MARK: - Properties

    private var sut: ImageGenerationViewModel!
    private var mockGenerateImage: MockGenerateImageUseCase!
    private var mockFetchModels: MockFetchModelsUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockGenerateImage = MockGenerateImageUseCase()
        mockFetchModels = MockFetchModelsUseCase()
        sut = ImageGenerationViewModel(
            generateImageUseCase: mockGenerateImage,
            fetchModelsUseCase: mockFetchModels
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockGenerateImage = nil
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
        let models = [
            LLMModel(id: "dall-e-3", mode: .imageGeneration),
            LLMModel(id: "dall-e-2", mode: .imageGeneration)
        ]
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
        XCTAssertEqual(loadedState.selectedModel, "dall-e-3")
        XCTAssertTrue(loadedState.generatedImages.isEmpty)
        XCTAssertNil(loadedState.errorMessage)
    }

    func test_send_viewAppeared_filtersNonImageCapableModels() async throws {
        // Given
        let models = [
            LLMModel(id: "dall-e-3", mode: .imageGeneration),
            LLMModel(id: "gpt-4", mode: .chat),
            LLMModel(id: "gpt-image-1", mode: .imageGeneration),
            LLMModel(id: "text-embedding", mode: .embedding),
            LLMModel(id: "whisper-1", mode: .audioTranscription)
        ]
        mockFetchModels.result = .success(models)

        // When
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.availableModels.count, 3)
        XCTAssertTrue(loadedState.availableModels.allSatisfy { $0.mode == .imageGeneration || $0.mode == .chat })
        XCTAssertNil(loadedState.availableModels.first(where: { $0.id == "text-embedding" }))
        XCTAssertNil(loadedState.availableModels.first(where: { $0.id == "whisper-1" }))
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

    // MARK: - Tests — promptChanged

    func test_send_promptChanged_updatesPrompt() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "dall-e-3", mode: .imageGeneration)])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.promptChanged("A cat in space"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.prompt, "A cat in space")
    }

    // MARK: - Tests — modelSelected

    func test_send_modelSelected_updatesModel() async throws {
        // Given
        mockFetchModels.result = .success([
            LLMModel(id: "dall-e-3", mode: .imageGeneration),
            LLMModel(id: "dall-e-2", mode: .imageGeneration)
        ])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.modelSelected("dall-e-2"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedModel, "dall-e-2")
    }

    // MARK: - Tests — sizeSelected

    func test_send_sizeSelected_updatesSize() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "dall-e-3", mode: .imageGeneration)])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.sizeSelected("512x512"))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.selectedSize, "512x512")
    }

    // MARK: - Tests — generateTapped

    func test_send_generateTapped_withValidInput_generatesImage() async throws {
        // Given
        let image = GeneratedImage(prompt: "A cat", imageData: Data([1, 2, 3]), modelId: "dall-e-3")
        mockFetchModels.result = .success([LLMModel(id: "dall-e-3", mode: .imageGeneration)])
        mockGenerateImage.result = .success(image)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.promptChanged("A cat"))

        // When
        sut.send(.generateTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.generatedImages.count, 1)
        XCTAssertFalse(loadedState.isGenerating)
        XCTAssertTrue(loadedState.prompt.isEmpty)
        XCTAssertTrue(mockGenerateImage.executeCalled)
    }

    func test_send_generateTapped_withEmptyPrompt_doesNotGenerate() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "dall-e-3", mode: .imageGeneration)])
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.generateTapped)
        try await Task.sleep(for: .milliseconds(100))

        // Then
        XCTAssertFalse(mockGenerateImage.executeCalled)
    }

    func test_send_generateTapped_withError_setsErrorMessage() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "dall-e-3", mode: .imageGeneration)])
        mockGenerateImage.result = .failure(APIError.serverUnreachable)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        sut.send(.promptChanged("A cat"))

        // When
        sut.send(.generateTapped)
        try await Task.sleep(for: .milliseconds(200))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(loadedState.isGenerating)
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertTrue(loadedState.generatedImages.isEmpty)
    }
}
