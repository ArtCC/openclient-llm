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
final class MockUserProfileManager: UserProfileManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var profile: UserProfile = UserProfile()
    var savedProfile: UserProfile?

    // MARK: - Public

    func getProfile() -> UserProfile {
        profile
    }

    func saveProfile(_ profile: UserProfile) {
        savedProfile = profile
        self.profile = profile
    }
}
