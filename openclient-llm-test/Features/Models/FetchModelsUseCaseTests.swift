//
//  FetchModelsUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class FetchModelsUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: FetchModelsUseCase!
    private var mockRepository: MockModelsRepository!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        mockRepository = MockModelsRepository()
        sut = FetchModelsUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil

        super.tearDown()
    }

    // MARK: - Tests

    func test_execute_withModels_returnsModels() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4", ownedBy: "openai"), LLMModel(id: "llama3", ownedBy: "ollama")]
        mockRepository.fetchModelsResult = .success(models)

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.id, "gpt-4")
    }

    func test_execute_withError_throwsError() async {
        // Given
        mockRepository.fetchModelsResult = .failure(APIError.serverUnreachable)

        // When / Then
        do {
            _ = try await sut.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is APIError)
        }
    }

    func test_execute_withEmptyList_returnsEmpty() async throws {
        // Given
        mockRepository.fetchModelsResult = .success([])

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertTrue(result.isEmpty)
    }
}
