//
//  PromptTemplateRepositoryCloudTests+Deletion.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

extension PromptTemplateRepositoryCloudTests {
    func test_loadAll_staleCloudPayloadWithEqualDurableMarker_physicallyCleansPayload() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let revision = Date(timeIntervalSince1970: 2_000)
        let template = PromptTemplate(title: "Stale", content: "Body", updatedAt: revision)
        context.cloud.cloudTemplates = [template]
        context.cloud.cloudTemplateDeletionMarkers[template.id] = CloudDeletionMarker(
            id: template.id,
            deletedAt: revision
        )

        // When
        let loaded = try await context.repository.loadAll()

        // Then
        XCTAssertFalse(loaded.contains { $0.id == template.id })
        XCTAssertFalse(context.cloud.cloudTemplates.contains { $0.id == template.id })
        XCTAssertEqual(context.cloud.applyTemplateDeletionCallCount, 1)
    }

    func test_delete_absentPayloadWithSufficientMarkers_doesNotAdvanceOrWriteMarker() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let marker = CloudDeletionMarker(id: UUID(), deletedAt: Date(timeIntervalSince1970: 2_000))
        context.cloud.cloudTemplateDeletionMarkers[marker.id] = marker
        let markerDirectory = context.directoryURL.appendingPathComponent(".DeletionMetadata", isDirectory: true)
        try FileManager.default.createDirectory(at: markerDirectory, withIntermediateDirectories: true)
        let markerURL = markerDirectory.appendingPathComponent("\(marker.id.uuidString).json")
        try encode(marker).write(
            to: markerURL,
            options: .atomic
        )
        let sentinel = Date(timeIntervalSince1970: 123)
        try FileManager.default.setAttributes([.modificationDate: sentinel], ofItemAtPath: markerURL.path)

        // When
        try await context.repository.delete(marker.id)

        // Then
        let attributes = try FileManager.default.attributesOfItem(atPath: markerURL.path)
        XCTAssertEqual(context.cloud.cloudTemplateDeletionMarkers[marker.id], marker)
        XCTAssertEqual(context.cloud.applyTemplateDeletionCallCount, 0)
        XCTAssertEqual(attributes[.modificationDate] as? Date, sentinel)
    }

    func test_delete_cloudContentChanged_repreflightsAndRetriesOnce() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let template = PromptTemplate(title: "Delete", content: "Body")
        context.cloud.cloudTemplates = [template]
        context.cloud.applyTemplateDeletionHandler = {
            context.cloud.applyTemplateDeletionHandler = nil
            context.cloud.cloudTemplates.append(PromptTemplate(title: "Concurrent", content: "Body"))
        }

        // When
        try await context.repository.delete(template.id)

        // Then
        XCTAssertEqual(context.cloud.applyTemplateDeletionCallCount, 2)
        XCTAssertFalse(context.cloud.cloudTemplates.contains { $0.id == template.id })
    }

    func test_save_queuedCloudOperationAfterIntentDisabled_doesNotWriteLocalOrCloud() async throws {
        // Given
        let context = try makeContext(cloudEnabled: true)
        defer { try? FileManager.default.removeItem(at: context.rootURL) }
        let blocker = TemplateOperationBlocker()
        let occupied = Task {
            try await context.operationGate.perform { try await blocker.wait() }
        }
        await blocker.waitUntilEntered()
        let template = PromptTemplate(title: "Cancelled", content: "Body")
        let save = Task { try await context.repository.save(template) }
        while await context.operationGate.pendingRequestCount < 1 { await Task.yield() }
        context.settings.isCloudSyncEnabled = false
        await blocker.resume()
        _ = try await occupied.value

        // When
        do {
            try await save.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Then
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: templateURL(template.id, in: context.directoryURL).path
            ))
            XCTAssertTrue(context.cloud.cloudTemplates.isEmpty)
        }
    }
}

private actor TemplateOperationBlocker {
    private var entered = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async throws {
        entered = true
        for waiter in enteredWaiters { waiter.resume() }
        enteredWaiters = []
        await withCheckedContinuation { continuation = $0 }
        try Task.checkCancellation()
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
