//
//  StreamMessageUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class StreamMessageUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: StreamMessageUseCase!
    private var mockRepository: MockChatRepository!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        mockRepository = MockChatRepository()
        sut = StreamMessageUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil

        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_withTokens_streamsAllTokens() async throws {
        // Given
        mockRepository.streamTokens = ["Hello", " ", "world", "!"]
        let messages = [ChatMessage(role: .user, content: "Hi")]

        // When
        var receivedTokens: [String] = []
        let stream = sut.execute(messages: messages, model: "gpt-4")
        for try await token in stream {
            receivedTokens.append(token)
        }

        // Then
        XCTAssertEqual(receivedTokens, ["Hello", " ", "world", "!"])
    }

    func test_execute_withError_throwsError() async {
        // Given
        mockRepository.streamError = APIError.streamingError("Stream failed")
        let messages = [ChatMessage(role: .user, content: "Hi")]

        // When / Then
        do {
            let stream = sut.execute(messages: messages, model: "gpt-4")
            for try await _ in stream {}
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
    }
}
