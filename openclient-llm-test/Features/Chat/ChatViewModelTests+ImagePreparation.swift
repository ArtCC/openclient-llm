//
//  ChatViewModelTests+ImagePreparation.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Tests - Image Preparation

@MainActor
extension ChatViewModelTests {
    func test_send_attachmentAdded_withConvertedImage_stagesPreparedImage() async throws {
        // Given
        let preparedData = Data([0xFF, 0xD8, 0xFF])
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockPrepareImageAttachment.result = .success(PreparedImageAttachment(
            data: preparedData,
            fileName: "photo.jpg",
            mimeType: "image/jpeg"
        ))
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.attachmentAdded(data: Data([0x00]), fileName: "photo.dng", type: .image))
        try await Task.sleep(for: .milliseconds(50))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        let attachment = try XCTUnwrap(loadedState.pendingAttachments.first)
        XCTAssertEqual(attachment.transientData, preparedData)
        XCTAssertEqual(attachment.fileName, "photo.jpg")
        XCTAssertEqual(attachment.mimeType, "image/jpeg")
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
    }

    func test_send_attachmentAdded_whenImagePreparationFails_showsErrorWithoutSaving() async throws {
        // Given
        mockFetchModels.result = .success([LLMModel(id: "gpt-4")])
        mockPrepareImageAttachment.result = .failure(APIError.invalidResponse)
        sut.send(.viewAppeared)
        try await Task.sleep(for: .milliseconds(100))

        // When
        sut.send(.attachmentAdded(data: Data([0x00]), fileName: "photo.dng", type: .image))
        try await Task.sleep(for: .milliseconds(50))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertTrue(loadedState.pendingAttachments.isEmpty)
        XCTAssertFalse(loadedState.isPreparingAttachment)
        XCTAssertNotNil(loadedState.errorMessage)
        XCTAssertTrue(mockAttachmentRepository.savedAttachments.isEmpty)
    }
}
