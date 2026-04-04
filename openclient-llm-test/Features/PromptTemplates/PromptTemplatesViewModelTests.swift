//
//  PromptTemplatesViewModelTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class PromptTemplatesViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: PromptTemplatesViewModel!
    var mockLoadTemplates: MockLoadPromptTemplatesUseCase!
    var mockSaveTemplate: MockSavePromptTemplateUseCase!
    var mockDeleteTemplate: MockDeletePromptTemplateUseCase!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockLoadTemplates = MockLoadPromptTemplatesUseCase()
        mockSaveTemplate = MockSavePromptTemplateUseCase()
        mockDeleteTemplate = MockDeletePromptTemplateUseCase()
        sut = PromptTemplatesViewModel(
            loadTemplatesUseCase: mockLoadTemplates,
            saveTemplateUseCase: mockSaveTemplate,
            deleteTemplateUseCase: mockDeleteTemplate
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockLoadTemplates = nil
        mockSaveTemplate = nil
        mockDeleteTemplate = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_loadsBuiltInsAndCustomSeparately() {
        // Given
        let builtIn = PromptTemplate(id: UUID(), title: "Coding", content: "You are...", isBuiltIn: true)
        let custom = PromptTemplate(id: UUID(), title: "My Template", content: "Custom prompt", isBuiltIn: false)
        mockLoadTemplates.result = .success([builtIn, custom])

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadedState.builtInTemplates, [builtIn])
        XCTAssertEqual(loadedState.customTemplates, [custom])
        XCTAssertNil(loadedState.errorMessage)
    }

    func test_send_viewAppeared_whenLoadFails_setsErrorMessage() {
        // Given
        let loadError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Load failed"])
        mockLoadTemplates.result = .failure(loadError)

        // When
        sut.send(.viewAppeared)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertTrue(loadedState.builtInTemplates.isEmpty)
        XCTAssertTrue(loadedState.customTemplates.isEmpty)
        XCTAssertEqual(loadedState.errorMessage, "Load failed")
    }

    func test_send_viewAppeared_incrementsLoadCallCount() {
        // Given
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.viewAppeared)

        // Then
        XCTAssertEqual(mockLoadTemplates.executeCallCount, 1)
    }

    // MARK: - Tests — saveTapped (create)

    func test_send_saveTapped_newTemplate_savesAndReloads() {
        // Given
        mockLoadTemplates.result = .success([])
        sut.send(.viewAppeared)

        let newTemplate = PromptTemplate(title: "New", content: "Content")
        mockLoadTemplates.result = .success([newTemplate])

        // When
        sut.send(.saveTapped(title: "New", content: "Content", editingTemplate: nil))

        // Then
        XCTAssertEqual(mockSaveTemplate.savedTemplates.count, 1)
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.title, "New")
        XCTAssertFalse(mockSaveTemplate.savedTemplates.first?.isBuiltIn ?? true)
    }

    func test_send_saveTapped_newTemplate_reloadsAfterSave() {
        // Given
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.saveTapped(title: "Title", content: "Body", editingTemplate: nil))

        // Then
        XCTAssertEqual(mockLoadTemplates.executeCallCount, 1)
    }

    // MARK: - Tests — saveTapped (edit)

    func test_send_saveTapped_editingTemplate_preservesIdAndCreatedAt() {
        // Given
        let existing = PromptTemplate(id: UUID(), title: "Old", content: "Old content", isBuiltIn: false)
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.saveTapped(title: "Updated", content: "Updated content", editingTemplate: existing))

        // Then
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.id, existing.id)
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.createdAt, existing.createdAt)
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.title, "Updated")
    }

    func test_send_saveTapped_whenSaveFails_setsErrorMessage() {
        // Given
        mockLoadTemplates.result = .success([])
        sut.send(.viewAppeared)
        mockSaveTemplate.error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])

        // When
        sut.send(.saveTapped(title: "T", content: "C", editingTemplate: nil))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadedState.errorMessage, "Save failed")
    }

    // MARK: - Tests — deleteTapped

    func test_send_deleteTapped_customTemplate_deletesAndReloads() {
        // Given
        let template = PromptTemplate(id: UUID(), title: "Custom", content: "Body", isBuiltIn: false)
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.deleteTapped(template))

        // Then
        XCTAssertEqual(mockDeleteTemplate.deletedIds, [template.id])
        XCTAssertEqual(mockLoadTemplates.executeCallCount, 1)
    }

    func test_send_deleteTapped_builtInTemplate_doesNotDelete() {
        // Given
        let builtIn = PromptTemplate(id: UUID(), title: "Built-in", content: "Body", isBuiltIn: true)
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.deleteTapped(builtIn))

        // Then
        XCTAssertTrue(mockDeleteTemplate.deletedIds.isEmpty)
    }

    func test_send_deleteTapped_whenDeleteFails_setsErrorMessage() {
        // Given
        let template = PromptTemplate(id: UUID(), title: "Custom", content: "Body", isBuiltIn: false)
        mockLoadTemplates.result = .success([])
        sut.send(.viewAppeared)
        let deleteError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
        mockDeleteTemplate.error = deleteError

        // When
        sut.send(.deleteTapped(template))

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadedState.errorMessage, "Delete failed")
    }
}
