//
//  SaveSelectedModelUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class SaveSelectedModelUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: SaveSelectedModelUseCase!
    private var mockSettingsManager: MockSettingsManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsManager = MockSettingsManager()
        sut = SaveSelectedModelUseCase(settingsManager: mockSettingsManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — execute

    func test_execute_withModelId_setsSelectedModel() {
        // When
        sut.execute(modelId: "gpt-4")

        // Then
        XCTAssertEqual(mockSettingsManager.selectedModelId, "gpt-4")
    }

    func test_execute_withNil_clearsSelectedModel() {
        // Given
        mockSettingsManager.selectedModelId = "gpt-4"

        // When
        sut.execute(modelId: nil)

        // Then
        XCTAssertNil(mockSettingsManager.selectedModelId)
    }

    func test_execute_overwritesPreviousSelection() {
        // Given
        mockSettingsManager.selectedModelId = "gpt-3.5"

        // When
        sut.execute(modelId: "gpt-4")

        // Then
        XCTAssertEqual(mockSettingsManager.selectedModelId, "gpt-4")
    }
}
