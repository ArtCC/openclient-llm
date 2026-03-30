//
//  OnboardingStep.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum OnboardingStep: CaseIterable, Sendable {
    case welcome
    case serverConfiguration
    case allSet
}
