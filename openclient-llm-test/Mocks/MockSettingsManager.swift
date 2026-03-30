//
//  MockSettingsManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

final class MockSettingsManager: SettingsManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    var isOnboardingCompleted: Bool = false
    var serverBaseURL: String = ""
}
