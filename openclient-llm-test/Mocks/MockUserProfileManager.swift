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
    var resolvedKeepLocal: Bool?

    // MARK: - Public

    func getProfile() -> UserProfile {
        profile
    }

    func saveProfile(_ profile: UserProfile) {
        savedProfile = profile
        self.profile = profile
    }

    func getLocalProfile() -> UserProfile {
        localProfile
    }

    func getCloudProfile() -> UserProfile? {
        cloudProfile
    }

    func resolveCloudSyncConflict(keepLocal: Bool) {
        resolvedKeepLocal = keepLocal
    }

    func deleteLocalProfile() {
        profile = UserProfile()
        localProfile = UserProfile()
    }
}
