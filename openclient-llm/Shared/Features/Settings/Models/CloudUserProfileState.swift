//
//  CloudUserProfileState.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum CloudUserProfileState: Equatable, Sendable {
    case missing
    case profile(UserProfile)
    case deleted(CloudDeletionMarker)
}
