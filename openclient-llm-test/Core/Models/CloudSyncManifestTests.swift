//
//  CloudSyncManifestTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class CloudSyncManifestTests: XCTestCase {
    func test_decode_missingData_returnsCurrentManifest() throws {
        // Given
        let data: Data? = nil

        // When
        let manifest = try CloudSyncManifest.decode(data)

        // Then
        XCTAssertEqual(manifest, .current)
    }

    func test_decode_currentManifest_returnsDecodedManifest() throws {
        // Given
        let data = try JSONEncoder().encode(CloudSyncManifest.current)

        // When
        let manifest = try CloudSyncManifest.decode(data)

        // Then
        XCTAssertEqual(manifest, .current)
    }

    func test_decode_unexpectedFormat_throwsInvalidFormat() throws {
        // Given
        let manifest = CloudSyncManifest(
            format: "invalid",
            schemaVersion: 1,
            minimumReaderVersion: 1
        )
        let data = try JSONEncoder().encode(manifest)

        // When
        XCTAssertThrowsError(try CloudSyncManifest.decode(data)) { error in
            // Then
            XCTAssertEqual(error as? CloudSyncManifest.ValidationError, .invalidFormat)
        }
    }

    func test_decode_invalidVersionRange_throwsInvalidVersionRange() throws {
        // Given
        let manifest = CloudSyncManifest(
            format: CloudSyncManifest.expectedFormat,
            schemaVersion: 1,
            minimumReaderVersion: 2
        )
        let data = try JSONEncoder().encode(manifest)

        // When
        XCTAssertThrowsError(try CloudSyncManifest.decode(data)) { error in
            // Then
            XCTAssertEqual(error as? CloudSyncManifest.ValidationError, .invalidVersionRange)
        }
    }

    func test_decode_newerAdditiveSchemaSupportingCurrentReader_returnsManifest() throws {
        // Given
        let manifest = CloudSyncManifest(
            format: CloudSyncManifest.expectedFormat,
            schemaVersion: 2,
            minimumReaderVersion: 1
        )
        let data = try JSONEncoder().encode(manifest)

        // When
        let decoded = try CloudSyncManifest.decode(data)

        // Then
        XCTAssertEqual(decoded, manifest)
    }

    func test_decode_newerSchemaRequiringNewerReader_throwsUnsupportedSchemaVersion() throws {
        // Given
        let manifest = CloudSyncManifest(
            format: CloudSyncManifest.expectedFormat,
            schemaVersion: 2,
            minimumReaderVersion: 2
        )
        let data = try JSONEncoder().encode(manifest)

        // When
        XCTAssertThrowsError(try CloudSyncManifest.decode(data)) { error in
            // Then
            XCTAssertEqual(error as? CloudSyncManifest.ValidationError, .unsupportedSchemaVersion(2))
        }
    }
}
