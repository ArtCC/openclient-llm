//
//  ChatViewModelTests+ImageGeneration.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests - Image Generation

@MainActor
extension ChatViewModelTests {
    func test_send_sendTapped_withImageGenerationModel_appendsGeneratedImage() async throws {
        // Given
        let imageData = Data([1, 2, 3])
        mockGenerateImage.result = .success(GeneratedImage(
            data: imageData,
            mimeType: "image/png",
            revisedPrompt: nil
        ))
        let imageModel = LLMModel(id: "gpt-image-2", mode: .imageGeneration)
        sut.state = .loaded(sut.makeLoadedState(models: [imageModel], pending: nil))
        let completed = expectation(description: "Background task completed")
        mockStreamingBackground.onEnd = { _ in completed.fulfill() }
        sut.send(.inputChanged("A cat on the Moon"))

        // When
        sut.send(.sendTapped)
        await fulfillment(of: [completed], timeout: 1)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(mockGenerateImage.prompts, ["A cat on the Moon"])
        XCTAssertEqual(mockGenerateImage.models, ["gpt-image-2"])
        XCTAssertEqual(loadedState.messages.last?.attachments.first?.type, .image)
        XCTAssertEqual(loadedState.messages.last?.attachments.first?.transientData, imageData)
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
        XCTAssertFalse(loadedState.isStreaming)
        XCTAssertEqual(mockStreamingBackground.beginCallCount, 1)
        XCTAssertEqual(mockStreamingBackground.phases, [.generatingImage, .saving])
        XCTAssertEqual(mockStreamingBackground.completionResults, [true])
        XCTAssertEqual(mockNotifyStreamingCompleted.completionCallCount, 1)
    }

    func test_send_sendTapped_imageGenerationFails_completesBackgroundTaskAsFailure() async {
        // Given
        mockGenerateImage.result = .failure(APIError.invalidResponse)
        let imageModel = LLMModel(id: "gpt-image-2", mode: .imageGeneration)
        sut.state = .loaded(sut.makeLoadedState(models: [imageModel], pending: nil))
        let completed = expectation(description: "Background task completed")
        mockStreamingBackground.onEnd = { _ in completed.fulfill() }
        sut.send(.inputChanged("A cat on the Moon"))

        // When
        sut.send(.sendTapped)
        await fulfillment(of: [completed], timeout: 1)

        // Then
        XCTAssertEqual(mockStreamingBackground.completionResults, [false])
        XCTAssertEqual(mockNotifyStreamingCompleted.completionCallCount, 0)
    }

    func test_performImageGeneration_oldPersistenceFinishes_doesNotEndNewBackgroundTask() async {
        // Given
        let persistenceGate = TestAsyncGate()
        let secondGenerationGate = TestAsyncGate()
        let firstPersistenceStarted = expectation(description: "First persistence started")
        let secondGenerationStarted = expectation(description: "Second generation started")
        mockSaveConversation.asyncExecuteHandler = { conversation, _, call in
            if call == 1 {
                firstPersistenceStarted.fulfill()
                await persistenceGate.wait()
            }
            return conversation
        }
        let generatedImage = GeneratedImage(
            data: Data([1, 2, 3]),
            mimeType: "image/png",
            revisedPrompt: nil
        )
        mockGenerateImage.asyncExecuteHandler = { _, _, call in
            if call == 2 {
                secondGenerationStarted.fulfill()
                await secondGenerationGate.wait()
            }
            return generatedImage
        }
        let imageModel = LLMModel(id: "gpt-image-2", mode: .imageGeneration)
        sut.state = .loaded(sut.makeLoadedState(models: [imageModel], pending: nil))
        sut.send(.inputChanged("First image"))
        sut.send(.sendTapped)
        await fulfillment(of: [firstPersistenceStarted], timeout: 1)
        let firstTask = sut.streamTask

        // When
        sut.send(.inputChanged("Second image"))
        sut.send(.sendTapped)
        await fulfillment(of: [secondGenerationStarted], timeout: 1)
        await persistenceGate.open()
        await firstTask?.value

        // Then
        XCTAssertEqual(mockStreamingBackground.beginCallCount, 2)
        XCTAssertTrue(mockStreamingBackground.isActive)
        XCTAssertEqual(mockStreamingBackground.completionResults, [false])

        // When
        let secondTaskCompleted = expectation(description: "Second background task completed")
        mockStreamingBackground.onEnd = { _ in secondTaskCompleted.fulfill() }
        await secondGenerationGate.open()
        await fulfillment(of: [secondTaskCompleted], timeout: 1)

        // Then
        XCTAssertEqual(mockStreamingBackground.completionResults, [false, true])
    }
}
