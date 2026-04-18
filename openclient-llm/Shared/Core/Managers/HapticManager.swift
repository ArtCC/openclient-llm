//
//  HapticManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - HapticManagerProtocol

protocol HapticManagerProtocol {
    func lightImpact()
    func mediumImpact()
    func heavyImpact()
}

// MARK: - HapticManager

#if os(iOS)
import SwiftUI

@MainActor
final class HapticManager: HapticManagerProtocol {
    // MARK: - Properties

    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Public functions

    func lightImpact() {
        lightImpactGenerator.impactOccurred()
    }

    func mediumImpact() {
        mediumImpactGenerator.impactOccurred()
    }

    func heavyImpact() {
        heavyImpactGenerator.impactOccurred()
    }
}
#else
/// macOS stub — haptics are not available on macOS.
final class HapticManager: HapticManagerProtocol {
    func lightImpact() {}
    func mediumImpact() {}
    func heavyImpact() {}
}
#endif
