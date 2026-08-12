//
//  UserProfileManager+Migration.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension UserProfileManager {
    func migrateFromUserDefaultsIfNeeded() throws {
        guard let url = localFileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        guard let data = defaults.data(forKey: Keys.legacyProfileData) else { return }
        let profile = try makeDecoder().decode(UserProfile.self, from: data)
        try saveToLocal(profile)
        defaults.removeObject(forKey: Keys.legacyProfileData)
    }

    func migrateLegacyKeysIfNeeded() throws {
        guard let url = localFileURL, !FileManager.default.fileExists(atPath: url.path) else { return }
        let localProfile = legacyProfile(
            name: defaults.string(forKey: "userProfile_name"),
            description: defaults.string(forKey: "userProfile_description"),
            extraInfo: defaults.string(forKey: "userProfile_extraInfo")
        )
        let cloudProfile = legacyProfile(
            name: legacyCloudStore.string(forKey: "userProfile_name"),
            description: legacyCloudStore.string(forKey: "userProfile_description"),
            extraInfo: legacyCloudStore.string(forKey: "userProfile_extraInfo")
        )
        let profile = localProfile.isEmpty ? cloudProfile : localProfile
        guard !profile.isEmpty else { return }
        try saveToLocal(profile)
        if !cloudProfile.isEmpty, cloudProfile != profile {
            try preserveForRecovery(cloudProfile)
        }
        cleanLegacyLocalKeys()
    }

    func cleanLegacyCloudKeysAfterVerifiedSync(synchronizedProfile: UserProfile?) throws {
        let keys = ["userProfile_name", "userProfile_description", "userProfile_extraInfo"]
        guard keys.contains(where: { legacyCloudStore.string(forKey: $0) != nil }) else { return }
        let legacyCloudProfile = legacyProfile(
            name: legacyCloudStore.string(forKey: "userProfile_name"),
            description: legacyCloudStore.string(forKey: "userProfile_description"),
            extraInfo: legacyCloudStore.string(forKey: "userProfile_extraInfo")
        )
        if !legacyCloudProfile.isEmpty, legacyCloudProfile != synchronizedProfile {
            try preserveForRecovery(legacyCloudProfile)
        }
        for key in keys {
            legacyCloudStore.removeObject(forKey: key)
        }
        legacyCloudStore.synchronize()
    }

    func cleanLegacyLocalKeys() {
        defaults.removeObject(forKey: "userProfile_name")
        defaults.removeObject(forKey: "userProfile_description")
        defaults.removeObject(forKey: "userProfile_extraInfo")
    }

    func legacyProfile(name: String?, description: String?, extraInfo: String?) -> UserProfile {
        UserProfile(
            name: name ?? "",
            profileDescription: description ?? "",
            extraInfo: extraInfo ?? "",
            modifiedAt: .distantPast
        )
    }
}
