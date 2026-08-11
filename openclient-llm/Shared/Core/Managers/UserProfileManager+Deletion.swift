//
//  UserProfileManager+Deletion.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension UserProfileManager {
    func deleteLocalProfile() throws {
        try removeLocalProfileFile()
        if let localDeletionFileURL, FileManager.default.fileExists(atPath: localDeletionFileURL.path) {
            try FileManager.default.removeItem(at: localDeletionFileURL)
        }
        if let recoveryDirectoryURL, FileManager.default.fileExists(atPath: recoveryDirectoryURL.path) {
            try FileManager.default.removeItem(at: recoveryDirectoryURL)
        }
    }

    func deleteProfile() async throws {
        let requiredCloudIntent = settingsManager.getIsCloudSyncEnabled()
        guard requiredCloudIntent else {
            try deleteLocalProfile()
            return
        }
        try await mutationGate.perform {
            try await self.checkCloudIntent(requiredCloudIntent)
            try await self.deleteSynchronizedProfileSerialized()
        }
    }

    func deleteSynchronizedProfile() async throws {
        let requiredCloudIntent = settingsManager.getIsCloudSyncEnabled()
        guard requiredCloudIntent else { throw CloudDataManagementError.cloudSyncDisabled }
        try await mutationGate.perform {
            try await self.checkCloudIntent(requiredCloudIntent)
            try await self.deleteSynchronizedProfileSerialized()
        }
    }

    func purgeLocalProfile(through marker: CloudPurgeMarker) throws {
        if case .profile(let profile) = try getLocalProfileState(), profile.modifiedAt <= marker.deletedAt {
            try removeLocalProfileFile()
        }
        if let localMarker = try loadLocalDeletionMarker(), localMarker.deletedAt <= marker.deletedAt,
           let localDeletionFileURL, FileManager.default.fileExists(atPath: localDeletionFileURL.path) {
            try FileManager.default.removeItem(at: localDeletionFileURL)
        }
        try purgeRecoveryProfiles(through: marker)
    }

    func validateLocalReset() throws {
        _ = try getLocalProfileState()
        _ = try loadLocalDeletionMarker()
        guard let recoveryDirectoryURL,
              FileManager.default.fileExists(atPath: recoveryDirectoryURL.path) else { return }
        for url in try recoveryProfileURLs(in: recoveryDirectoryURL) {
            _ = try makeDecoder().decode(UserProfile.self, from: Data(contentsOf: url))
        }
    }

    func deleteSynchronizedProfileSerialized() async throws {
        let snapshot = try await cloudSyncManager.loadProfileSyncSnapshot()
        try checkCloudIntent(true)
        let localState = try getLocalProfileState()
        let localMarker = try loadLocalDeletionMarker()
        if case .missing = localState, case .deleted(let cloudMarker) = snapshot.state {
            if (localMarker?.deletedAt ?? .distantPast) < cloudMarker.deletedAt {
                try saveLocalDeletionMarker(cloudMarker)
            }
            return
        }
        if case .missing = localState, let localMarker {
            try await cloudSyncManager.applyProfileSyncOutput(.deleted(localMarker), basedOn: snapshot)
            return
        }
        let existingDate: Date
        switch snapshot.state {
        case .missing:
            existingDate = .distantPast
        case .profile(let profile):
            existingDate = profile.modifiedAt
        case .deleted(let marker):
            existingDate = marker.deletedAt
        }
        let localDate = localMarker?.deletedAt ?? .distantPast
        let marker = CloudDeletionMarker(
            id: CloudSyncManager.profileMarkerId,
            deletedAt: nextRevision(after: max(existingDate, localDate))
        )
        try saveLocalDeletionMarker(marker)
        try await cloudSyncManager.applyProfileSyncOutput(.deleted(marker), basedOn: snapshot)
        try removeLocalProfileFile()
    }

    func applyRemoteDeletion(_ marker: CloudDeletionMarker, localState: LocalUserProfileState) throws {
        guard case .profile(let local) = localState, local.modifiedAt <= marker.deletedAt else { return }
        try preserveForRecovery(local)
        try removeLocalProfileFile()
    }

    private func purgeRecoveryProfiles(through marker: CloudPurgeMarker) throws {
        guard let recoveryDirectoryURL,
              FileManager.default.fileExists(atPath: recoveryDirectoryURL.path) else { return }
        for url in try recoveryProfileURLs(in: recoveryDirectoryURL) {
            let profile = try makeDecoder().decode(UserProfile.self, from: Data(contentsOf: url))
            if profile.modifiedAt <= marker.deletedAt {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    private func recoveryProfileURLs(in directoryURL: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }
}
