//
//  TwoDeviceCategoryCloudTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class TwoDeviceProfileCloudTests: XCTestCase {
    func test_synchronize_profileAOnlyThenNewerB_convergesInBothDirections() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let fromA = UserProfile(name: "A", modifiedAt: revision(1_000))
        try await saveLocalProfile(fromA, on: harness.deviceA)

        // When
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        let synchronizedRevision = harness.deviceB.profile.getLocalProfile().modifiedAt
        let fromB = UserProfile(name: "B", modifiedAt: synchronizedRevision.addingTimeInterval(1))
        try await saveLocalProfile(fromB, on: harness.deviceB)
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)

        // Then
        XCTAssertEqual(harness.deviceA.profile.getLocalProfile().name, "B")
        XCTAssertEqual(harness.deviceB.profile.getLocalProfile().name, "B")
    }

    func test_synchronize_equalDivergentProfile_reportsConflictThenResolutionDownloadsToSecondDevice() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        try await saveLocalProfile(
            UserProfile(name: "A", modifiedAt: revision(1_000)),
            on: harness.deviceA
        )
        _ = await harness.synchronize(harness.deviceA)
        let synchronizedA = harness.deviceA.profile.getLocalProfile()
        try await saveLocalProfile(
            UserProfile(name: "B", modifiedAt: synchronizedA.modifiedAt),
            on: harness.deviceB
        )

        // When
        let conflict = await harness.synchronize(harness.deviceB)
        try await harness.deviceB.profile.resolveCloudSyncConflict(keepLocal: true)
        _ = await harness.synchronize(harness.deviceA)
        let recoveredProfiles = try recoveryData(
            in: harness.deviceB.documentsURL,
            folder: "ProfileRecovery"
        ).map { try SyncJSONCoding.makeDecoder().decode(UserProfile.self, from: $0) }

        // Then
        XCTAssertEqual(conflict.outcomes[.profile], .conflict)
        XCTAssertEqual(harness.deviceA.profile.getLocalProfile().name, "B")
        XCTAssertEqual(harness.deviceB.profile.getLocalProfile().name, "B")
        XCTAssertTrue(recoveredProfiles.contains(synchronizedA))
    }

    func test_synchronize_equalIdenticalProfile_isNoOp() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let profile = UserProfile(name: "Same", modifiedAt: revision(1_000))
        try await saveLocalProfile(profile, on: harness.deviceA)
        try await saveLocalProfile(profile, on: harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        let bytes = try harness.cloudBytes()

        // When
        let result = await harness.synchronize(harness.deviceA)

        // Then
        XCTAssertEqual(result.outcomes[.profile], .synchronized)
        XCTAssertEqual(try harness.cloudBytes(), bytes)
    }

    func test_delete_staleProfileCannotResurrectButExplicitRecreationSurvives() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let original = UserProfile(name: "Original", modifiedAt: revision(1_000))
        try await saveLocalProfile(original, on: harness.deviceA)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        try await harness.deviceA.profile.deleteProfile()
        guard case .deleted(let marker) = try await harness.deviceB.profile.getCloudProfileState() else {
            return XCTFail("Expected a cloud deletion")
        }
        try await saveLocalProfile(
            UserProfile(name: original.name, modifiedAt: marker.deletedAt.addingTimeInterval(-1)),
            on: harness.deviceB
        )
        guard case .profile(let staleProfile) = try harness.deviceB.profile.getLocalProfileState() else {
            return XCTFail("Expected a stale local profile")
        }
        XCTAssertLessThanOrEqual(staleProfile.modifiedAt, marker.deletedAt)

        // When
        let deletionResult = await harness.synchronize(harness.deviceB)
        XCTAssertEqual(deletionResult.outcomes[.profile], .synchronized)
        XCTAssertEqual(try harness.deviceB.profile.getLocalProfileState(), .missing)
        try await harness.deviceB.profile.saveProfile(UserProfile(name: "Recreated", modifiedAt: revision(100)))
        _ = await harness.synchronize(harness.deviceA)

        // Then
        XCTAssertEqual(harness.deviceA.profile.getLocalProfile().name, "Recreated")
        XCTAssertEqual(harness.deviceB.profile.getLocalProfile().name, "Recreated")
    }

    private func saveLocalProfile(
        _ profile: UserProfile,
        on device: TwoDeviceCloudHarness.Device
    ) async throws {
        device.settings.setIsCloudSyncEnabled(false)
        try await device.profile.saveProfile(profile)
        device.settings.setIsCloudSyncEnabled(true)
    }
}

@MainActor
final class TwoDeviceMemoryCloudTests: XCTestCase {
    func test_synchronize_disjointItemsAndSameRecordConflict_convergesDeterministically() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let commonID = UUID()
        let local = item(id: commonID, content: "Alpha", updatedAt: 2_000)
        let remote = item(id: commonID, content: "Beta", updatedAt: 2_000)
        try write([local, item(content: "Only A", updatedAt: 1_000)], to: harness.deviceA, name: "Memory.json")
        try write([remote, item(content: "Only B", updatedAt: 1_000)], to: harness.deviceB, name: "Memory.json")

        // When
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)
        let winner = try XCTUnwrap(harness.deviceA.memory.getItems().first { $0.id == commonID })
        let loser = winner == local ? remote : local
        let recovered = try SyncJSONCoding.makeDecoder().decode(
            [MemoryItem].self,
            from: Data(contentsOf: harness.deviceB.documentsURL.appendingPathComponent("MemoryRecovery.json"))
        )

        // Then
        XCTAssertEqual(harness.deviceA.memory.getItems(), harness.deviceB.memory.getItems())
        XCTAssertEqual(harness.deviceA.memory.getItems().count, 3)
        XCTAssertTrue(recovered.contains(loser))
    }

    func test_delete_staleDeviceCannotResurrectButNewerRecreationSurvives() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let original = item(content: "Original", updatedAt: 1_000)
        try write([original], to: harness.deviceA, name: "Memory.json")
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        try await harness.deviceA.memory.delete(id: original.id)

        // When
        _ = await harness.synchronize(harness.deviceB)
        XCTAssertTrue(harness.deviceB.memory.getItems().isEmpty)
        let recreated = item(id: original.id, content: "Recreated", updatedAt: 4_000_000_000)
        try write([recreated], to: harness.deviceB, name: "Memory.json")
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)

        // Then
        XCTAssertEqual(harness.deviceA.memory.getItems().map(\.content), ["Recreated"])
        XCTAssertEqual(harness.deviceB.memory.getItems().map(\.content), ["Recreated"])
    }

    func test_synchronize_newerItemsInBothDirections_selectsEachNewestItem() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let firstID = UUID()
        let secondID = UUID()
        try write(
            [item(id: firstID, content: "A old", updatedAt: 1_000),
             item(id: secondID, content: "A new", updatedAt: 4_000)],
            to: harness.deviceA,
            name: "Memory.json"
        )
        try write(
            [item(id: firstID, content: "B new", updatedAt: 2_000),
             item(id: secondID, content: "B old", updatedAt: 3_000)],
            to: harness.deviceB,
            name: "Memory.json"
        )

        // When
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)

        // Then
        let values = Dictionary(uniqueKeysWithValues: harness.deviceA.memory.getItems().map { ($0.id, $0.content) })
        XCTAssertEqual(values[firstID], "B new")
        XCTAssertEqual(values[secondID], "A new")
    }
}

@MainActor
final class TwoDevicePromptTemplateCloudTests: XCTestCase {
    func test_synchronize_localOnlyBothDirectionsAndDisjointChanges_converges() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let fromA = template(title: "Only A", updatedAt: 1_000)
        let fromB = template(title: "Only B", updatedAt: 2_000)
        try write(fromA, to: harness.deviceA)
        try write(fromB, to: harness.deviceB)

        // When
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)

        // Then
        let idsA = Set(try await harness.deviceA.customTemplates().map(\.id))
        let idsB = Set(try await harness.deviceB.customTemplates().map(\.id))
        XCTAssertEqual(idsA, Set([fromA.id, fromB.id]))
        XCTAssertEqual(idsB, Set([fromA.id, fromB.id]))
    }

    func test_synchronize_equalDivergentTemplate_recoversLoserAndIsByteIdempotent() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let id = UUID()
        let fromA = template(id: id, title: "Alpha", updatedAt: 1_000)
        let fromB = template(id: id, title: "Beta", updatedAt: 1_000)
        let fromABytes = try SyncJSONCoding.makeEncoder().encode(fromA)
        let fromBBytes = try SyncJSONCoding.makeEncoder().encode(fromB)
        try write(fromA, to: harness.deviceA)
        try write(fromB, to: harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)
        let cloudBytes = try harness.cloudBytes()

        // When
        _ = await harness.synchronize(harness.deviceB)

        // Then
        let templatesA = try await harness.deviceA.customTemplates()
        let templatesB = try await harness.deviceB.customTemplates()
        let winner = try XCTUnwrap(templatesA.first)
        let losingBytes = winner == fromA ? fromBBytes : fromABytes
        let recoveredBytes = try recoveryData(
            in: harness.deviceA.documentsURL,
            folder: "PromptTemplateRecovery"
        ) + recoveryData(in: harness.deviceB.documentsURL, folder: "PromptTemplateRecovery")
        XCTAssertEqual(templatesA, templatesB)
        XCTAssertEqual(try harness.cloudBytes(), cloudBytes)
        XCTAssertTrue(recoveredBytes.contains(losingBytes))
        XCTAssertEqual(
            try SyncJSONCoding.makeDecoder().decode(PromptTemplate.self, from: losingBytes),
            winner == fromA ? fromB : fromA
        )
    }

    func test_synchronize_newerTemplatesInBothDirections_selectsEachNewestTemplate() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let firstID = UUID()
        let secondID = UUID()
        try write(template(id: firstID, title: "A old", updatedAt: 1_000), to: harness.deviceA)
        try write(template(id: secondID, title: "A new", updatedAt: 4_000), to: harness.deviceA)
        try write(template(id: firstID, title: "B new", updatedAt: 2_000), to: harness.deviceB)
        try write(template(id: secondID, title: "B old", updatedAt: 3_000), to: harness.deviceB)

        // When
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)

        // Then
        let templates = try await harness.deviceA.customTemplates()
        let values = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.title) })
        XCTAssertEqual(values[firstID], "B new")
        XCTAssertEqual(values[secondID], "A new")
    }

    func test_delete_staleDeviceCannotResurrectButNewerRecreationSurvives() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let original = template(title: "Original", updatedAt: 1_000)
        try write(original, to: harness.deviceA)
        _ = await harness.synchronize(harness.deviceA)
        _ = await harness.synchronize(harness.deviceB)
        try await harness.deviceA.templates.delete(original.id)

        // When
        _ = await harness.synchronize(harness.deviceB)
        let recreated = template(id: original.id, title: "Recreated", updatedAt: 4_000_000_000)
        try write(recreated, to: harness.deviceB)
        _ = await harness.synchronize(harness.deviceB)
        _ = await harness.synchronize(harness.deviceA)

        // Then
        let titlesA = try await harness.deviceA.customTemplates().map(\.title)
        let titlesB = try await harness.deviceB.customTemplates().map(\.title)
        XCTAssertEqual(titlesA, ["Recreated"])
        XCTAssertEqual(titlesB, ["Recreated"])
    }
}

// MARK: - Shared Helpers

private func revision(_ value: TimeInterval) -> Date {
    Date(timeIntervalSince1970: value)
}

private func item(id: UUID = UUID(), content: String, updatedAt: TimeInterval) -> MemoryItem {
    MemoryItem(id: id, content: content, createdAt: revision(500), updatedAt: revision(updatedAt))
}

private func template(id: UUID = UUID(), title: String, updatedAt: TimeInterval) -> PromptTemplate {
    PromptTemplate(
        id: id,
        title: title,
        content: "Body",
        createdAt: revision(500),
        updatedAt: revision(updatedAt)
    )
}

private func write<Value: Encodable>(
    _ value: Value,
    to device: TwoDeviceCloudHarness.Device,
    name: String
) throws {
    try SyncJSONCoding.makeEncoder().encode(value).write(
        to: device.documentsURL.appendingPathComponent(name),
        options: .atomic
    )
}

private func write(_ template: PromptTemplate, to device: TwoDeviceCloudHarness.Device) throws {
    let directory = device.documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try SyncJSONCoding.makeEncoder().encode(template).write(
        to: directory.appendingPathComponent("\(template.id.uuidString).json"),
        options: .atomic
    )
}

private func recoveryData(in documentsURL: URL, folder: String) throws -> [Data] {
    let url = documentsURL.appendingPathComponent(folder, isDirectory: true)
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    return try files.map { try Data(contentsOf: $0) }
}
