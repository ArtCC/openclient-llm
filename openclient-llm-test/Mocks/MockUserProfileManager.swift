//
//  MockUserProfileManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
@MainActor
final class MockUserProfileManager: UserProfileManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var profile: UserProfile = UserProfile()
    var savedProfile: UserProfile?
    var localProfile: UserProfile {
        get {
            guard case .profile(let profile) = localProfileState else { return UserProfile(modifiedAt: .distantPast) }
            return profile
        }
        set { localProfileState = .profile(newValue) }
    }
    var localProfileState: LocalUserProfileState = .missing
    var localProfileError: Error?
    var cloudProfile: UserProfile?
    var cloudProfileDeletionMarker: CloudDeletionMarker?
    var resolvedKeepLocal: Bool?
    var resolveCloudSyncConflictHandler: (@Sendable (Bool) async throws -> Void)?
    var resolveCloudSyncConflictCallCount = 0
    var conflictCancellationCallCount = 0
    var cloudError: Error?
    var getCloudProfileCallCount = 0
    var deleteLocalProfileError: Error?
    var deleteProfileCalled = false

    // MARK: - Public

    func getProfile() -> UserProfile {
        profile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        if let cloudError { throw cloudError }
        savedProfile = profile
        self.profile = profile
    }

    func getLocalProfile() -> UserProfile {
        localProfile
    }

    func getLocalProfileState() throws -> LocalUserProfileState {
        if let localProfileError { throw localProfileError }
        return localProfileState
    }

    func getCloudProfileState() async throws -> CloudUserProfileState {
        getCloudProfileCallCount += 1
        if let cloudError { throw cloudError }
        if let cloudProfileDeletionMarker { return .deleted(cloudProfileDeletionMarker) }
        return cloudProfile.map(CloudUserProfileState.profile) ?? .missing
    }

    func resolveCloudSyncConflict(keepLocal: Bool) async throws {
        resolveCloudSyncConflictCallCount += 1
        if let cloudError { throw cloudError }
        do {
            try await resolveCloudSyncConflictHandler?(keepLocal)
            try Task.checkCancellation()
            resolvedKeepLocal = keepLocal
        } catch is CancellationError {
            conflictCancellationCallCount += 1
            throw CancellationError()
        }
    }

    func deleteProfile() async throws {
        if let cloudError { throw cloudError }
        deleteProfileCalled = true
        try deleteLocalProfile()
    }

    func deleteSynchronizedProfile() async throws {
        try await deleteProfile()
    }

    func deleteLocalProfile() throws {
        if let deleteLocalProfileError { throw deleteLocalProfileError }
        profile = UserProfile()
        localProfileState = .missing
    }

    func purgeLocalProfile(through marker: CloudPurgeMarker) throws {
        if let deleteLocalProfileError { throw deleteLocalProfileError }
        if case .profile(let profile) = localProfileState, profile.modifiedAt <= marker.deletedAt {
            localProfileState = .missing
        }
    }

    func validateLocalReset() throws {
        if let deleteLocalProfileError { throw deleteLocalProfileError }
        if let localProfileError { throw localProfileError }
    }
}
