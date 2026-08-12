//
//  UserProfileManager+Reconciliation.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension UserProfileManager {
    func saveProfileSerialized(_ profile: UserProfile, requiredCloudIntent: Bool) async throws {
        let snapshot = try await cloudSyncManager.loadProfileSyncSnapshot()
        try checkCloudIntent(requiredCloudIntent)
        var profile = profile
        if case .deleted(let marker) = snapshot.state, profile.modifiedAt <= marker.deletedAt {
            profile.modifiedAt = nextRevision(after: marker.deletedAt)
        }
        try await synchronizeSavedProfile(
            profile,
            basedOn: snapshot,
            canRetry: true,
            requiredCloudIntent: requiredCloudIntent
        )
    }

    func resolveCloudSyncConflictSerialized(keepLocal: Bool, requiredCloudIntent: Bool) async throws {
        let snapshot = try await cloudSyncManager.loadProfileSyncSnapshot()
        try checkCloudIntent(requiredCloudIntent)
        let state = snapshot.state
        let localState = try getLocalProfileState()
        if keepLocal {
            try await resolveConflictKeepingLocal(
                state: state,
                localState: localState,
                snapshot: snapshot,
                requiredCloudIntent: requiredCloudIntent
            )
        } else {
            try await resolveConflictKeepingCloud(
                state: state,
                localState: localState,
                snapshot: snapshot,
                requiredCloudIntent: requiredCloudIntent
            )
        }
    }

    func synchronizeSavedProfile(
        _ profile: UserProfile,
        basedOn snapshot: CloudUserProfileSnapshot,
        canRetry: Bool,
        requiredCloudIntent: Bool
    ) async throws {
        do {
            let output = try await reconcileSavedProfile(
                profile,
                with: snapshot,
                requiredCloudIntent: requiredCloudIntent
            )
            try checkCloudIntent(requiredCloudIntent)
            try saveToLocal(output)
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.profile(output), basedOn: snapshot)
            try cleanLegacyCloudKeysAfterVerifiedSync(synchronizedProfile: output)
        } catch CloudSyncError.cloudContentChanged where canRetry {
            let refreshedSnapshot = try await cloudSyncManager.loadProfileSyncSnapshot()
            try checkCloudIntent(requiredCloudIntent)
            try await synchronizeSavedProfile(
                profile,
                basedOn: refreshedSnapshot,
                canRetry: false,
                requiredCloudIntent: requiredCloudIntent
            )
        }
    }

    func reconcileSavedProfile(
        _ local: UserProfile,
        with snapshot: CloudUserProfileSnapshot,
        requiredCloudIntent: Bool
    ) async throws -> UserProfile {
        switch snapshot.state {
        case .missing:
            return local
        case .deleted(let marker):
            guard local.modifiedAt > marker.deletedAt else {
                try checkCloudIntent(requiredCloudIntent)
                try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
                try preserveForRecovery(local)
                try removeLocalProfileFile()
                try cleanLegacyCloudKeysAfterVerifiedSync(synchronizedProfile: nil)
                throw CloudSyncError.staleProfileRevision
            }
            return local
        case .profile(let cloud):
            return try await reconcileSavedProfile(
                local,
                with: cloud,
                snapshot: snapshot,
                requiredCloudIntent: requiredCloudIntent
            )
        }
    }

    private func resolveConflictKeepingLocal(
        state: CloudUserProfileState,
        localState: LocalUserProfileState,
        snapshot: CloudUserProfileSnapshot,
        requiredCloudIntent: Bool
    ) async throws {
        guard case .profile(var local) = localState else {
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
            return
        }
        if case .deleted(let marker) = state, local.modifiedAt <= marker.deletedAt {
            try preserveForRecovery(local)
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
            try removeLocalProfileFile()
            try cleanLegacyCloudKeysAfterVerifiedSync(synchronizedProfile: nil)
            return
        }
        if case .profile(let cloud) = state, cloud != local {
            try preserveForRecovery(cloud)
        }
        local.modifiedAt = nextRevision(after: state)
        try saveToLocal(local)
        try checkCloudIntent(requiredCloudIntent)
        try await cloudSyncManager.applyProfileSyncOutput(.profile(local), basedOn: snapshot)
        try cleanLegacyCloudKeysAfterVerifiedSync(synchronizedProfile: local)
    }

    private func resolveConflictKeepingCloud(
        state: CloudUserProfileState,
        localState: LocalUserProfileState,
        snapshot: CloudUserProfileSnapshot,
        requiredCloudIntent: Bool
    ) async throws {
        switch state {
        case .missing:
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
            return
        case .profile(let cloud):
            if case .profile(let local) = localState, local != cloud {
                try preserveForRecovery(local)
            }
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
            try saveToLocal(cloud)
        case .deleted(let marker):
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
            try applyRemoteDeletion(marker, localState: localState)
        }
        let synchronizedProfile: UserProfile?
        if case .profile(let profile) = state {
            synchronizedProfile = profile
        } else {
            synchronizedProfile = nil
        }
        try cleanLegacyCloudKeysAfterVerifiedSync(synchronizedProfile: synchronizedProfile)
    }

    private func reconcileSavedProfile(
        _ local: UserProfile,
        with cloud: UserProfile,
        snapshot: CloudUserProfileSnapshot,
        requiredCloudIntent: Bool
    ) async throws -> UserProfile {
        if cloud.modifiedAt > local.modifiedAt {
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
            try preserveForRecovery(local)
            try saveToLocal(cloud)
            try cleanLegacyCloudKeysAfterVerifiedSync(synchronizedProfile: cloud)
            throw CloudSyncError.staleProfileRevision
        }
        if cloud.modifiedAt == local.modifiedAt, cloud != local {
            try checkCloudIntent(requiredCloudIntent)
            try await cloudSyncManager.applyProfileSyncOutput(.unchanged, basedOn: snapshot)
            try preserveForRecovery(local)
            try preserveForRecovery(cloud)
            throw CloudSyncError.conflictingProfileRevision
        }
        if cloud != local {
            try preserveForRecovery(cloud)
        }
        return local
    }
}
