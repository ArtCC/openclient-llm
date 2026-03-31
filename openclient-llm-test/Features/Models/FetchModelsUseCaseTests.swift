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

    override func setUp() async throws {
        try await super.setUp()

        mockRepository = MockModelsRepository()
        sut = FetchModelsUseCase(repository: mockRepository)
    }

    override func tearDown() async throws {
        sut = nil
        mockRepository = nil

        try await super.tearDown()
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

    func test_execute_mergesCapabilitiesFromModelInfo() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4", ownedBy: "openai"), LLMModel(id: "llama3", ownedBy: "ollama")]
        mockRepository.fetchModelsResult = .success(models)

        let modelInfoList = [LLMModel(id: "gpt-4", capabilities: [.vision, .functionCalling])]
        mockRepository.fetchModelInfoResult = .success(modelInfoList)

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first(where: { $0.id == "gpt-4" })?.capabilities, [.vision, .functionCalling])
        XCTAssertTrue(result.first(where: { $0.id == "llama3" })?.capabilities.isEmpty == true)
    }

    func test_execute_mergesModeFromModelInfo() async throws {
        // Given
        let models = [
            LLMModel(id: "dall-e-3", ownedBy: "openai"),
            LLMModel(id: "gpt-4", ownedBy: "openai")
        ]
        mockRepository.fetchModelsResult = .success(models)

        let modelInfoList = [
            LLMModel(id: "dall-e-3", mode: .imageGeneration),
            LLMModel(id: "gpt-4", mode: .chat)
        ]
        mockRepository.fetchModelInfoResult = .success(modelInfoList)

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result.first(where: { $0.id == "dall-e-3" })?.mode, .imageGeneration)
        XCTAssertEqual(result.first(where: { $0.id == "gpt-4" })?.mode, .chat)
    }

    func test_execute_modelInfoFailure_stillReturnsModels() async throws {
        // Given
        let models = [LLMModel(id: "gpt-4")]
        mockRepository.fetchModelsResult = .success(models)
        mockRepository.fetchModelInfoResult = .failure(APIError.serverUnreachable)

        // When
        let result = try await sut.execute()

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first?.capabilities.isEmpty == true)
    }
}
