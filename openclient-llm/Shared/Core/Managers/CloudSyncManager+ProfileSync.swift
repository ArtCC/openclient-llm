//
//  CloudSyncManager+ProfileSync.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension CloudSyncManager {
    func loadProfileSyncSnapshot() async throws -> CloudUserProfileSnapshot {
        try await categoryOperationGate.perform {
            let session = try makeCategorySession()
            return try await fileCoordinator.read(at: session.containerURL) { containerURL in
                try validateCategorySession(session)
                let snapshot = try makeProfileSnapshot(session: session, containerURL: containerURL)
                try validateCategorySession(session)
                return snapshot
            }
        }
    }

    func applyProfileSyncOutput(
        _ output: CloudUserProfileSyncOutput,
        basedOn snapshot: CloudUserProfileSnapshot
    ) async throws {
        try await categoryOperationGate.perform {
            try validateCategorySession(snapshot.session)
            try await fileCoordinator.write(at: snapshot.session.containerURL, options: []) { containerURL in
                try validateCategorySession(snapshot.session)
                let current = try makeProfileSnapshot(session: snapshot.session, containerURL: containerURL)
                guard current.profileData == snapshot.profileData,
                      current.deletionMarkerData == snapshot.deletionMarkerData,
                      current.purgeMarker == snapshot.purgeMarker else {
                    throw CloudSyncError.cloudContentChanged
                }
                switch output {
                case .unchanged:
                    break
                case .profile(let profile):
                    try validateProfileOutput(profile, against: current.state)
                    try writeProfileOutput(profile, session: snapshot.session, containerURL: containerURL)
                case .deleted(let marker):
                    try writeProfileDeletion(marker, session: snapshot.session, containerURL: containerURL)
                }
                try validateCategorySession(snapshot.session)
            }
        }
    }
}

// MARK: - Private

private extension CloudSyncManager {
    func makeProfileSnapshot(
        session: CloudSyncSession,
        containerURL: URL
    ) throws -> CloudUserProfileSnapshot {
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try validateCategoryManifest(in: documentsURL)
        let profileURL = documentsURL.appendingPathComponent("UserProfile.json")
        let markerURL = documentsURL.appendingPathComponent("UserProfileDeletion.json")
        try requireCategoryFileReady(at: profileURL)
        try requireCategoryFileReady(at: markerURL)
        let profileData = try profileDataIfPresent(at: profileURL)
        let markerData = try profileDataIfPresent(at: markerURL)
        let purgeMarker = try readPurgeMarker(in: documentsURL)
        let decoder = SyncJSONCoding.makeDecoder()
        let profile = try profileData.map { try decoder.decode(UserProfile.self, from: $0) }
        let marker = try markerData.map { try decoder.decode(CloudDeletionMarker.self, from: $0) }
        if let marker, marker.id != Self.profileMarkerId {
            throw CloudSyncError.cloudContentChanged
        }
        let state: CloudUserProfileState
        let effectiveDeletionDate = [marker?.deletedAt, purgeMarker?.deletedAt].compactMap { $0 }.max()
        if let effectiveDeletionDate, (profile?.modifiedAt ?? .distantPast) <= effectiveDeletionDate {
            state = .deleted(CloudDeletionMarker(id: Self.profileMarkerId, deletedAt: effectiveDeletionDate))
        } else if let profile {
            state = .profile(profile)
        } else {
            state = .missing
        }
        return CloudUserProfileSnapshot(
            session: session,
            state: state,
            profileData: profileData,
            deletionMarkerData: markerData,
            purgeMarker: purgeMarker
        )
    }

    func validateProfileOutput(_ profile: UserProfile, against state: CloudUserProfileState) throws {
        switch state {
        case .missing:
            break
        case .deleted(let marker):
            guard profile.modifiedAt > marker.deletedAt else { throw CloudSyncError.staleProfileRevision }
        case .profile(let current):
            guard profile.modifiedAt >= current.modifiedAt else { throw CloudSyncError.staleProfileRevision }
            if profile.modifiedAt == current.modifiedAt, profile != current {
                throw CloudSyncError.conflictingProfileRevision
            }
        }
    }

    func profileDataIfPresent(at url: URL) throws -> Data? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func writeProfileOutput(
        _ profile: UserProfile,
        session: CloudSyncSession,
        containerURL: URL
    ) throws {
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try ensureDirectoryExists(at: documentsURL)
        try writeCategoryManifestIfNeeded(in: documentsURL)
        try validateCategorySession(session)
        let profileURL = documentsURL.appendingPathComponent("UserProfile.json")
        let markerURL = documentsURL.appendingPathComponent("UserProfileDeletion.json")
        try writeEncoded(profile, to: profileURL)
        try validateCategorySession(session)
        let writtenData = try Data(contentsOf: profileURL)
        let writtenProfile = try SyncJSONCoding.makeDecoder().decode(UserProfile.self, from: writtenData)
        let marker = try decodeIfPresent(CloudDeletionMarker.self, at: markerURL)
        let isNewerThanPurge = try readPurgeMarker(in: documentsURL)
            .map { profile.modifiedAt > $0.deletedAt } ?? true
        guard writtenProfile == profile,
              marker.map({ profile.modifiedAt > $0.deletedAt }) ?? true,
              isNewerThanPurge else {
            throw CloudSyncError.cloudContentChanged
        }
    }

    func writeProfileDeletion(
        _ proposedMarker: CloudDeletionMarker,
        session: CloudSyncSession,
        containerURL: URL
    ) throws {
        guard proposedMarker.id == Self.profileMarkerId else { throw CloudSyncError.invalidProfileData }
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        try ensureDirectoryExists(at: documentsURL)
        try writeCategoryManifestIfNeeded(in: documentsURL)
        let markerURL = documentsURL.appendingPathComponent("UserProfileDeletion.json")
        let existing = try decodeIfPresent(CloudDeletionMarker.self, at: markerURL)
        let marker = existing.map { $0.deletedAt >= proposedMarker.deletedAt ? $0 : proposedMarker } ?? proposedMarker
        try writeEncoded(marker, to: markerURL)
        try validateCategorySession(session)
        let profileURL = documentsURL.appendingPathComponent("UserProfile.json")
        if let profile = try decodeIfPresent(UserProfile.self, at: profileURL),
           profile.modifiedAt <= marker.deletedAt {
            try removeCategoryItemIfPresent(at: profileURL)
        }
    }
}
