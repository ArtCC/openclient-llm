//
//  GetConversationStartersUseCaseTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class GetConversationStartersUseCaseTests: XCTestCase {
    // MARK: - Properties

    private var sut: GetConversationStartersUseCase!
    private var mockManager: MockConversationStartersManager!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockManager = MockConversationStartersManager()
        sut = GetConversationStartersUseCase(manager: mockManager)
    }

    override func tearDown() async throws {
        sut = nil
        mockManager = nil

        try await super.tearDown()
    }

    // MARK: - Tests — execute

    func test_execute_withDefaultCount_returnsStarters() {
        // Given
        let starters = sut.execute(count: 4)

        // Then
        XCTAssertEqual(starters.count, 4)
    }

    func test_execute_withSmallerCount_returnsRequestedNumber() {
        // Given
        let starters = sut.execute(count: 2)

        // Then
        XCTAssertEqual(starters.count, 2)
    }

    func test_execute_withLargerCount_returnsAvailableStarters() {
        // Given
        let starters = sut.execute(count: 10)

        // Then
        XCTAssertEqual(starters.count, 4)
    }

    func test_execute_returnsDistinctStarters() {
        // Given
        let starters = sut.execute(count: 3)

        // Then
        let ids = Set(starters.map(\.id))
        XCTAssertEqual(ids.count, starters.count)
    }
}
