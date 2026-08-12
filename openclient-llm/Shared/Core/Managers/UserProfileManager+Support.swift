//
//  UserProfileManager+Support.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CryptoKit
import Foundation

extension UserProfileManager {
    func saveToLocal(_ profile: UserProfile) throws {
        guard let url = localFileURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try makeEncoder().encode(profile)
        try data.write(to: url, options: .atomic)
        let storedProfile = try makeDecoder().decode(UserProfile.self, from: Data(contentsOf: url))
        guard try makeEncoder().encode(storedProfile) == data else { throw CloudSyncError.cloudContentChanged }
    }

    func checkCloudIntent(_ requiredCloudIntent: Bool) throws {
        try Task.checkCancellation()
        guard !requiredCloudIntent || settingsManager.getIsCloudSyncEnabled() else { throw CancellationError() }
    }

    func removeLocalProfileFile() throws {
        guard let localFileURL, FileManager.default.fileExists(atPath: localFileURL.path) else { return }
        try FileManager.default.removeItem(at: localFileURL)
    }

    func loadLocalDeletionMarker() throws -> CloudDeletionMarker? {
        guard let localDeletionFileURL,
              FileManager.default.fileExists(atPath: localDeletionFileURL.path) else { return nil }
        return try makeDecoder().decode(CloudDeletionMarker.self, from: Data(contentsOf: localDeletionFileURL))
    }

    func saveLocalDeletionMarker(_ marker: CloudDeletionMarker) throws {
        guard let localDeletionFileURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try makeEncoder().encode(marker)
        try data.write(to: localDeletionFileURL, options: .atomic)
        let storedMarker = try makeDecoder().decode(
            CloudDeletionMarker.self,
            from: Data(contentsOf: localDeletionFileURL)
        )
        guard storedMarker == marker else { throw CloudSyncError.invalidProfileData }
    }

    func nextRevision(after revision: Date) -> Date {
        let currentMilliseconds = Int64((Date().timeIntervalSinceReferenceDate * 1_000).rounded())
        let revisionMilliseconds = Int64((revision.timeIntervalSinceReferenceDate * 1_000).rounded())
        let nextMilliseconds = max(currentMilliseconds, revisionMilliseconds) + 1
        return UserProfile.canonicalRevision(
            Date(timeIntervalSinceReferenceDate: Double(nextMilliseconds) / 1_000)
        )
    }

    func nextRevision(after state: CloudUserProfileState) -> Date {
        let remoteRevision: Date
        switch state {
        case .missing:
            remoteRevision = .distantPast
        case .profile(let profile):
            remoteRevision = profile.modifiedAt
        case .deleted(let marker):
            remoteRevision = marker.deletedAt
        }
        return nextRevision(after: remoteRevision)
    }

    func preserveForRecovery(_ profile: UserProfile) throws {
        guard let recoveryDirectoryURL else { throw CocoaError(.fileNoSuchFile) }
        let data = try makeEncoder().encode(profile)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = recoveryDirectoryURL.appendingPathComponent("\(digest).json")
        if FileManager.default.fileExists(atPath: url.path) {
            guard try Data(contentsOf: url) == data else { throw CloudSyncError.cloudContentChanged }
            return
        }
        try FileManager.default.createDirectory(at: recoveryDirectoryURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        let recovered = try makeDecoder().decode(UserProfile.self, from: Data(contentsOf: url))
        guard try makeEncoder().encode(recovered) == data else { throw CloudSyncError.cloudContentChanged }
    }

    func makeEncoder() -> JSONEncoder {
        SyncJSONCoding.makeEncoder()
    }

    func makeDecoder() -> JSONDecoder {
        SyncJSONCoding.makeDecoder()
    }
}
