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
        sut.send(.inputChanged("A cat on the Moon"))

        // When
        sut.send(.sendTapped)
        for _ in 0..<20 { await Task.yield() }

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
    }
}
