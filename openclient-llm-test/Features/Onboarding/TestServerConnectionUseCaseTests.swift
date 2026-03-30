//
//  TestServerConnectionUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class TestServerConnectionUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: TestServerConnectionUseCase!
    private var mockRepository: MockOnboardingRepository!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockRepository = MockOnboardingRepository()
        sut = TestServerConnectionUseCase(repository: mockRepository)
    }

    override func tearDown() async throws {
        sut = nil
        mockRepository = nil

        try await super.tearDown()
    }

    // MARK: - Tests

    func test_execute_success_doesNotThrow() async throws {
        // Given
        mockRepository.testConnectionResult = .success(())

        // When / Then
        try await sut.execute(serverURL: "https://example.com", apiKey: "key")
    }

    func test_execute_failure_throwsError() async {
        // Given
        mockRepository.testConnectionResult = .failure(OnboardingRepositoryError.serverUnreachable)

        // When / Then
        do {
            try await sut.execute(serverURL: "https://example.com", apiKey: "key")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnboardingRepositoryError)
        }
    }

    func test_execute_invalidURL_throwsError() async {
        // Given
        mockRepository.testConnectionResult = .failure(OnboardingRepositoryError.invalidURL)

        // When / Then
        do {
            try await sut.execute(serverURL: "", apiKey: "")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnboardingRepositoryError)
        }
    }
}
