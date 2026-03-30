//
//  SendMessageUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SendMessageUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: SendMessageUseCase!
    private var mockRepository: MockChatRepository!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        mockRepository = MockChatRepository()
        sut = SendMessageUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil

        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_withValidMessage_returnsResponse() async throws {
        // Given
        mockRepository.sendMessageResult = .success("Hello! How can I help?")
        let messages = [ChatMessage(role: .user, content: "Hello")]

        // When
        let response = try await sut.execute(messages: messages, model: "gpt-4")

        // Then
        XCTAssertEqual(response, "Hello! How can I help?")
    }

    func test_execute_withError_throwsError() async {
        // Given
        mockRepository.sendMessageResult = .failure(APIError.serverUnreachable)
        let messages = [ChatMessage(role: .user, content: "Hello")]

        // When / Then
        do {
            _ = try await sut.execute(messages: messages, model: "gpt-4")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }
}
