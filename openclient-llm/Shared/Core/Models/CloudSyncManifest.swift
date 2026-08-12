//
//  CloudSyncManifest.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct CloudSyncManifest: Codable, Equatable, Sendable {
    // MARK: - Properties

    enum ValidationError: Error, Equatable, Sendable {
        case invalidFormat
        case invalidVersionRange
        case unsupportedSchemaVersion(Int)
    }

    static let expectedFormat = "com.artcc.openclient-llm.icloud-sync"
    static let currentSchemaVersion = 1

    let format: String
    let schemaVersion: Int
    let minimumReaderVersion: Int

    static var current: CloudSyncManifest {
        CloudSyncManifest(
            format: expectedFormat,
            schemaVersion: currentSchemaVersion,
            minimumReaderVersion: currentSchemaVersion
        )
    }

    // MARK: - Decode

    static func decode(_ data: Data?) throws -> CloudSyncManifest {
        guard let data else { return .current }
        let manifest = try JSONDecoder().decode(CloudSyncManifest.self, from: data)
        try manifest.validate()
        return manifest
    }

    // MARK: - Validate

    func validate(supportedSchemaVersion: Int = currentSchemaVersion) throws {
        guard format == Self.expectedFormat else {
            throw ValidationError.invalidFormat
        }
        guard schemaVersion > 0,
              minimumReaderVersion > 0,
              minimumReaderVersion <= schemaVersion else {
            throw ValidationError.invalidVersionRange
        }
        guard minimumReaderVersion <= supportedSchemaVersion else {
            throw ValidationError.unsupportedSchemaVersion(schemaVersion)
        }
    }
}
