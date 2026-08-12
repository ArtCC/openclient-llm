//
//  TwoDeviceConversationCloudTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class TwoDeviceConversationCloudTests: XCTestCase {
    // MARK: - Tests

    func test_synchronize_deviceAOnlyConversation_deviceBDownloadsConversationAndAttachment() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let bytes = Data([0x01, 0x02, 0x03, 0x04])
        let conversation = makeConversation(title: "A", revision: 1_000, attachmentBytes: bytes)
        try harness.deviceA.writeConversation(conversation.value)
        try harness.deviceA.writeAttachment(bytes, for: conversation.attachment)

        // When
        let resultA = await harness.deviceA.conversations.synchronize()
        let resultB = await harness.deviceB.conversations.synchronize()

        // Then
        let downloaded = try await harness.deviceB.conversations.loadLocal()
        XCTAssertEqual(resultA, .synchronized)
        XCTAssertEqual(resultB, .synchronized)
        XCTAssertEqual(downloaded, [conversation.value])
        let attachmentURL = harness.deviceB.documentsURL
            .appendingPathComponent(conversation.attachment.fileRelativePath)
        XCTAssertEqual(try Data(contentsOf: attachmentURL), bytes)
    }

    func test_synchronize_deviceBOnlyAndDeviceAOnly_disjointChangesConverge() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let fromA = makeConversation(title: "A", revision: 1_000).value
        let fromB = makeConversation(title: "B", revision: 2_000).value
        try harness.deviceA.writeConversation(fromA)
        try harness.deviceB.writeConversation(fromB)

        // When
        _ = await harness.deviceB.conversations.synchronize()
        _ = await harness.deviceA.conversations.synchronize()
        _ = await harness.deviceB.conversations.synchronize()

        // Then
        let expected = Set([fromA.id, fromB.id])
        let idsA = Set(try await harness.deviceA.conversations.loadLocal().map(\.id))
        let idsB = Set(try await harness.deviceB.conversations.loadLocal().map(\.id))
        XCTAssertEqual(idsA, expected)
        XCTAssertEqual(idsB, expected)
    }

    func test_synchronize_equalIdenticalConversation_repeatedRunsAreByteIdempotent() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let conversation = makeConversation(title: "Same", revision: 1_000).value
        try harness.deviceA.writeConversation(conversation)
        try harness.deviceB.writeConversation(conversation)
        _ = await harness.deviceA.conversations.synchronize()
        _ = await harness.deviceB.conversations.synchronize()
        let cloudBytes = try harness.cloudBytes()
        let localABytes = try harness.bytes(in: harness.deviceA.documentsURL)
        let localBBytes = try harness.bytes(in: harness.deviceB.documentsURL)

        // When
        _ = await harness.deviceB.conversations.synchronize()
        _ = await harness.deviceA.conversations.synchronize()

        // Then
        XCTAssertEqual(try harness.cloudBytes(), cloudBytes)
        XCTAssertEqual(try harness.bytes(in: harness.deviceA.documentsURL), localABytes)
        XCTAssertEqual(try harness.bytes(in: harness.deviceB.documentsURL), localBBytes)
    }

    func test_synchronize_newerRecordInEitherDirection_selectsNewestRecord() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let idA = fixedUUID("90000000-0000-0000-0000-000000000001")
        let olderA = makeConversation(id: idA, title: "A old", revision: 1_000).value
        let newerB = makeConversation(id: idA, title: "B new", revision: 2_000).value
        let idB = fixedUUID("90000000-0000-0000-0000-000000000002")
        let newerA = makeConversation(id: idB, title: "A new", revision: 4_000).value
        let olderB = makeConversation(id: idB, title: "B old", revision: 3_000).value
        try harness.deviceA.writeConversation(olderA)
        try harness.deviceA.writeConversation(newerA)
        try harness.deviceB.writeConversation(newerB)
        try harness.deviceB.writeConversation(olderB)

        // When
        _ = await harness.deviceA.conversations.synchronize()
        _ = await harness.deviceB.conversations.synchronize()
        _ = await harness.deviceA.conversations.synchronize()

        // Then
        let conversations = try await harness.deviceA.conversations.loadLocal()
        XCTAssertEqual(conversations.first { $0.id == idA }?.title, newerB.title)
        XCTAssertEqual(conversations.first { $0.id == idB }?.title, newerA.title)
    }

    func test_synchronize_equalDivergentRecord_convergesDeterministicallyAndRecoversLoser() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let id = fixedUUID("90000000-0000-0000-0000-000000000003")
        let local = makeConversation(id: id, title: "Alpha", revision: 1_000).value
        let remote = makeConversation(id: id, title: "Beta", revision: 1_000).value
        let localBytes = try SyncJSONCoding.makeEncoder().encode(local)
        let remoteBytes = try SyncJSONCoding.makeEncoder().encode(remote)
        try harness.deviceA.writeConversation(local)
        try harness.deviceB.writeConversation(remote)

        // When
        _ = await harness.deviceA.conversations.synchronize()
        _ = await harness.deviceB.conversations.synchronize()
        _ = await harness.deviceA.conversations.synchronize()

        // Then
        let conversationsA = try await harness.deviceA.conversations.loadLocal()
        let conversationsB = try await harness.deviceB.conversations.loadLocal()
        let winnerA = try XCTUnwrap(conversationsA.first)
        let winnerB = try XCTUnwrap(conversationsB.first)
        let losingBytes = winnerA == local ? remoteBytes : localBytes
        let recoveredBytes = try recoveryData(in: harness.deviceA.documentsURL)
            + recoveryData(in: harness.deviceB.documentsURL)
        XCTAssertEqual(winnerA, winnerB)
        XCTAssertTrue(recoveredBytes.contains(losingBytes))
        XCTAssertEqual(
            try SyncJSONCoding.makeDecoder().decode(Conversation.self, from: losingBytes),
            winnerA == local ? remote : local
        )
    }

    func test_delete_deviceAWhileDeviceBStale_tombstoneBlocksResurrection() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let conversation = makeConversation(title: "Delete", revision: 1_000).value
        try harness.deviceA.writeConversation(conversation)
        _ = await harness.deviceA.conversations.synchronize()
        _ = await harness.deviceB.conversations.synchronize()

        // When
        try await harness.deviceA.conversations.delete(conversation.id)
        _ = await harness.deviceB.conversations.synchronize()
        _ = await harness.deviceA.conversations.synchronize()

        // Then
        let localA = try await harness.deviceA.conversations.loadLocal()
        let localB = try await harness.deviceB.conversations.loadLocal()
        XCTAssertTrue(localA.isEmpty)
        XCTAssertTrue(localB.isEmpty)
    }

    func test_synchronize_newerRecreationAfterDelete_survivesOnBothDevices() async throws {
        // Given
        let harness = try TwoDeviceCloudHarness()
        let original = makeConversation(title: "Original", revision: 1_000).value
        try harness.deviceA.writeConversation(original)
        _ = await harness.deviceA.conversations.synchronize()
        _ = await harness.deviceB.conversations.synchronize()
        try await harness.deviceA.conversations.delete(original.id)
        let recreated = makeConversation(id: original.id, title: "Recreated", revision: 4_000_000_000).value
        try harness.deviceB.writeConversation(recreated)

        // When
        _ = await harness.deviceB.conversations.synchronize()
        _ = await harness.deviceA.conversations.synchronize()

        // Then
        let titleA = try await harness.deviceA.conversations.loadLocal().first?.title
        let titleB = try await harness.deviceB.conversations.loadLocal().first?.title
        XCTAssertEqual(titleA, "Recreated")
        XCTAssertEqual(titleB, "Recreated")
    }
}

// MARK: - Private

private extension TwoDeviceConversationCloudTests {
    typealias AttachedConversation = (value: Conversation, attachment: ChatMessage.Attachment)

    func makeConversation(
        id: UUID = UUID(),
        title: String,
        revision: TimeInterval,
        attachmentBytes: Data? = nil
    ) -> AttachedConversation {
        let attachment = ChatMessage.Attachment(
            id: UUID(),
            type: .image,
            fileName: "fixture.png",
            mimeType: "image/png",
            fileRelativePath: "Attachments/\(id.uuidString)/fixture.png"
        )
        let attachments = attachmentBytes == nil ? [] : [attachment]
        let date = Date(timeIntervalSince1970: revision)
        let message = ChatMessage(role: .user, content: title, timestamp: date, attachments: attachments)
        return (
            Conversation(id: id, title: title, modelId: "model", messages: [message], createdAt: date, updatedAt: date),
            attachment
        )
    }

    func fixedUUID(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }

    func recoveryData(in documentsURL: URL) throws -> [Data] {
        let url = documentsURL.appendingPathComponent("ConversationRecovery", isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return try files.filter { $0.pathExtension == "json" }.map { try Data(contentsOf: $0) }
    }
}
