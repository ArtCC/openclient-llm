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
    func test_send_attachmentAdded_withConvertedImage_savesPreparedImage() async throws {
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
        let record = try XCTUnwrap(mockAttachmentRepository.savedAttachments.first)
        XCTAssertEqual(record.data, preparedData)
        XCTAssertEqual(record.attachment.fileName, "photo.jpg")
        XCTAssertEqual(record.attachment.mimeType, "image/jpeg")
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
