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
    var localProfile: UserProfile = UserProfile()
    var cloudProfile: UserProfile?
    var cloudProfileDeletionMarker: CloudDeletionMarker?
    var resolvedKeepLocal: Bool?
    var cloudError: Error?
    var getCloudProfileCallCount = 0
    var deleteLocalProfileError: Error?

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

    func getCloudProfile() async throws -> UserProfile? {
        getCloudProfileCallCount += 1
        if let cloudError { throw cloudError }
        return cloudProfile
    }

    func getCloudProfileState() async throws -> CloudUserProfileState {
        getCloudProfileCallCount += 1
        if let cloudError { throw cloudError }
        if let cloudProfileDeletionMarker { return .deleted(cloudProfileDeletionMarker) }
        return cloudProfile.map(CloudUserProfileState.profile) ?? .missing
    }

    func resolveCloudSyncConflict(keepLocal: Bool) async throws {
        if let cloudError { throw cloudError }
        resolvedKeepLocal = keepLocal
    }

    func deleteLocalProfile() throws {
        if let deleteLocalProfileError { throw deleteLocalProfileError }
        profile = UserProfile()
        localProfile = UserProfile()
    }
}
