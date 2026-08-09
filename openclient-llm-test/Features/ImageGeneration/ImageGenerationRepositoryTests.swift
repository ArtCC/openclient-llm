//
//  ImageGenerationRepositoryTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ImageGenerationRepositoryTests: XCTestCase {
    func test_generateImage_withBase64Response_returnsDecodedImage() async throws {
        // Given
        let imageData = Data([1, 2, 3])
        let apiClient = MockAPIClient()
        apiClient.requestResult = ImageGenerationResponse(data: [
            .init(url: nil, b64Json: imageData.base64EncodedString(), revisedPrompt: "A lunar cat")
        ])
        let sut = ImageGenerationRepository(apiClient: apiClient)

        // When
        let result = try await sut.generateImage(prompt: "A cat", model: "gpt-image-2")

        // Then
        XCTAssertEqual(result.data, imageData)
        XCTAssertEqual(result.mimeType, "image/png")
        XCTAssertEqual(apiClient.lastRequestEndpoint, "images/generations")
        XCTAssertEqual(apiClient.lastRequestTimeoutInterval, 600)
    }
}
