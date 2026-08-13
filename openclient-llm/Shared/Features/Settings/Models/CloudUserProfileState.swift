//
//  CloudUserProfileState.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum LocalUserProfileState: Equatable, Sendable {
    case missing
    case profile(UserProfile)
}

nonisolated enum CloudUserProfileState: Equatable, Sendable {
    case missing
    case profile(UserProfile)
    case deleted(CloudDeletionMarker)
}

nonisolated struct CloudUserProfileSnapshot: Equatable, Sendable {
    let session: CloudSyncSession
    let state: CloudUserProfileState
    let profileData: Data?
    let deletionMarkerData: Data?
    var purgeMarker: CloudPurgeMarker?

    init(
        session: CloudSyncSession,
        state: CloudUserProfileState,
        profileData: Data?,
        deletionMarkerData: Data?,
        purgeMarker: CloudPurgeMarker? = nil
    ) {
        self.session = session
        self.state = state
        self.profileData = profileData
        self.deletionMarkerData = deletionMarkerData
        self.purgeMarker = purgeMarker
    }
}

nonisolated enum CloudUserProfileSyncOutput: Equatable, Sendable {
    case unchanged
    case profile(UserProfile)
    case deleted(CloudDeletionMarker)
}
