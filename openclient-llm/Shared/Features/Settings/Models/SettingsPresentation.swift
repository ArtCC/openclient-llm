//
//  SettingsPresentation.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum SettingsPresentation: String, Identifiable, Sendable {
    case feedback
    case tipJar

    var id: Self { self }
}
