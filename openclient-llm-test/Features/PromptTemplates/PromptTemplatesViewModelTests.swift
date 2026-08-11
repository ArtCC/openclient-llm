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
    var mockAppReviewManager: MockAppReviewManager!
    var notificationCenter: NotificationCenter!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        mockLoadTemplates = MockLoadPromptTemplatesUseCase()
        mockSaveTemplate = MockSavePromptTemplateUseCase()
        mockDeleteTemplate = MockDeletePromptTemplateUseCase()
        mockAppReviewManager = MockAppReviewManager()
        notificationCenter = NotificationCenter()
        sut = PromptTemplatesViewModel(
            loadTemplatesUseCase: mockLoadTemplates,
            saveTemplateUseCase: mockSaveTemplate,
            deleteTemplateUseCase: mockDeleteTemplate,
            appReviewManager: mockAppReviewManager,
            notificationCenter: notificationCenter
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockLoadTemplates = nil
        mockSaveTemplate = nil
        mockDeleteTemplate = nil
        mockAppReviewManager = nil
        notificationCenter = nil

        try await super.tearDown()
    }

    // MARK: - Tests — Init

    func test_init_defaultState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Tests — viewAppeared

    func test_send_viewAppeared_loadsBuiltInsAndCustomSeparately() async {
        // Given
        let builtIn = PromptTemplate(id: UUID(), title: "Coding", content: "You are...", isBuiltIn: true)
        let custom = PromptTemplate(id: UUID(), title: "My Template", content: "Custom prompt", isBuiltIn: false)
        mockLoadTemplates.result = .success([builtIn, custom])

        // When
        sut.send(.viewAppeared)
        await waitUntil { self.mockLoadTemplates.executeCallCount == 1 }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadedState.builtInTemplates, [builtIn])
        XCTAssertEqual(loadedState.customTemplates, [custom])
        XCTAssertNil(loadedState.errorMessage)
    }

    func test_send_viewAppeared_whenLoadFails_setsErrorMessage() async {
        // Given
        let loadError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Load failed"])
        mockLoadTemplates.result = .failure(loadError)

        // When
        sut.send(.viewAppeared)
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.errorMessage != nil
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertTrue(loadedState.builtInTemplates.isEmpty)
        XCTAssertTrue(loadedState.customTemplates.isEmpty)
        XCTAssertEqual(loadedState.errorMessage, "Load failed")
    }

    func test_send_viewAppeared_incrementsLoadCallCount() async {
        // Given
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.viewAppeared)
        await waitUntil { self.mockLoadTemplates.executeCallCount == 1 }

        // Then
        XCTAssertEqual(mockLoadTemplates.executeCallCount, 1)
    }

    func test_notification_promptTemplatesChanged_reloadsTemplates() async {
        // Given
        mockLoadTemplates.result = .success([])

        // When
        notificationCenter.post(name: .promptTemplatesDidChangeExternally, object: nil)
        await waitUntil { self.mockLoadTemplates.executeCallCount == 1 }

        // Then
        XCTAssertEqual(mockLoadTemplates.executeCallCount, 1)
    }

    // MARK: - Tests — saveTapped (create)

    func test_send_saveTapped_newTemplate_savesAndReloads() async {
        // Given
        mockLoadTemplates.result = .success([])
        sut.send(.viewAppeared)

        let newTemplate = PromptTemplate(title: "New", content: "Content")
        mockLoadTemplates.result = .success([newTemplate])

        // When
        sut.send(.saveTapped(title: "New", content: "Content", editingTemplate: nil))
        await waitUntil { self.mockSaveTemplate.savedTemplates.count == 1 }

        // Then
        XCTAssertEqual(mockSaveTemplate.savedTemplates.count, 1)
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.title, "New")
        XCTAssertFalse(mockSaveTemplate.savedTemplates.first?.isBuiltIn ?? true)
        XCTAssertEqual(mockAppReviewManager.requestReviewCallCount, 1)
    }

    func test_send_saveTapped_newTemplate_reloadsAfterSave() async {
        // Given
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.saveTapped(title: "Title", content: "Body", editingTemplate: nil))
        await waitUntil { self.mockLoadTemplates.executeCallCount == 1 }

        // Then
        XCTAssertEqual(mockLoadTemplates.executeCallCount, 1)
    }

    // MARK: - Tests — saveTapped (edit)

    func test_send_saveTapped_editingTemplate_preservesIdAndCreatedAt() async {
        // Given
        let existing = PromptTemplate(id: UUID(), title: "Old", content: "Old content", isBuiltIn: false)
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.saveTapped(title: "Updated", content: "Updated content", editingTemplate: existing))
        await waitUntil { self.mockSaveTemplate.savedTemplates.count == 1 }

        // Then
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.id, existing.id)
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.createdAt, existing.createdAt)
        XCTAssertGreaterThan(mockSaveTemplate.savedTemplates.first?.updatedAt ?? .distantPast, existing.updatedAt)
        XCTAssertEqual(mockSaveTemplate.savedTemplates.first?.title, "Updated")
        XCTAssertEqual(mockAppReviewManager.requestReviewCallCount, 0)
    }

    func test_send_saveTapped_whenSaveFails_setsErrorMessage() async {
        // Given
        mockLoadTemplates.result = .success([])
        sut.send(.viewAppeared)
        mockSaveTemplate.error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])

        // When
        sut.send(.saveTapped(title: "T", content: "C", editingTemplate: nil))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.errorMessage == "Save failed"
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadedState.errorMessage, "Save failed")
        XCTAssertEqual(mockAppReviewManager.requestReviewCallCount, 0)
    }

    // MARK: - Tests — deleteTapped

    func test_send_deleteTapped_customTemplate_deletesAndReloads() async {
        // Given
        let template = PromptTemplate(id: UUID(), title: "Custom", content: "Body", isBuiltIn: false)
        mockLoadTemplates.result = .success([])

        // When
        sut.send(.deleteTapped(template))
        await waitUntil {
            self.mockDeleteTemplate.deletedIds == [template.id]
                && self.mockLoadTemplates.executeCallCount == 1
        }

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

    func test_send_deleteTapped_whenDeleteFails_setsErrorMessage() async {
        // Given
        let template = PromptTemplate(id: UUID(), title: "Custom", content: "Body", isBuiltIn: false)
        mockLoadTemplates.result = .success([])
        sut.send(.viewAppeared)
        let deleteError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
        mockDeleteTemplate.error = deleteError

        // When
        sut.send(.deleteTapped(template))
        await waitUntil {
            guard case .loaded(let state) = self.sut.state else { return false }
            return state.errorMessage == "Delete failed"
        }

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(loadedState.errorMessage, "Delete failed")
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Condition was not satisfied")
    }
}
