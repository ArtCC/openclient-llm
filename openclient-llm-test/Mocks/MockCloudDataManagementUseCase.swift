//
//  MockCloudDataManagementUseCase.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockCloudDataManagementUseCase: CloudDataManagementUseCaseProtocol, @unchecked Sendable {
    var inventoryResult = CloudDataInventory(categories: [:])
    var deletionResult = CloudDeletionResult(
        marker: CloudPurgeMarker(id: UUID(), deletedAt: Date()),
        outcomes: Dictionary(uniqueKeysWithValues: CloudDataCategory.allCases.map {
            ($0, CloudDeletionCategoryOutcome.deleted)
        })
    )
    var retryResult: CloudDeletionResult?
    var resumeResult: CloudDeletionResult?
    var operationError: Error?
    var resumeError: Error?
    var inventoryCallCount = 0
    var resumeCallCount = 0
    var calls: [String] = []
    var deletedConversationId: UUID?
    var deleteProfileCallCount = 0
    var deletedMemoryId: UUID?
    var deletedTemplateId: UUID?
    var deleteAllCallCount = 0
    var retryCallCount = 0

    func inventory() async -> CloudDataInventory {
        inventoryCallCount += 1
        calls.append("inventory")
        return inventoryResult
    }

    func deleteConversation(id: UUID) async throws {
        if let operationError { throw operationError }
        deletedConversationId = id
    }

    func deleteProfile() async throws {
        if let operationError { throw operationError }
        deleteProfileCallCount += 1
    }

    func deleteMemory(id: UUID) async throws {
        if let operationError { throw operationError }
        deletedMemoryId = id
    }

    func deletePromptTemplate(id: UUID) async throws {
        if let operationError { throw operationError }
        deletedTemplateId = id
    }

    func deleteAll() async throws -> CloudDeletionResult {
        if let operationError { throw operationError }
        deleteAllCallCount += 1
        return deletionResult
    }

    func retryDeletion(_ result: CloudDeletionResult) async throws -> CloudDeletionResult {
        if let operationError { throw operationError }
        retryCallCount += 1
        return retryResult ?? deletionResult
    }

    func resumeDeletion() async throws -> CloudDeletionResult? {
        resumeCallCount += 1
        calls.append("resumeDeletion")
        if let resumeError { throw resumeError }
        return resumeResult
    }
}
