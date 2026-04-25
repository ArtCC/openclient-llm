//
//  OpenClientApp.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 29/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

@main
struct OpenClientApp: App {
    // MARK: - Properties

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var shortcutManager = ShortcutManager.shared
    @State private var isObscured = false
    @Environment(\.scenePhase) private var scenePhase

    private let settingsManager: SettingsManagerProtocol = SettingsManager()

    // MARK: - View

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environment(shortcutManager)
                .overlay {
                    if isObscured {
                        PrivacyScreenView()
                            .animation(.easeInOut(duration: 0.2), value: isObscured)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard settingsManager.getIsPrivacyScreenEnabled() else { return }
                    switch newPhase {
                    case .active:
                        isObscured = false
                    case .inactive, .background:
                        isObscured = true
                    @unknown default:
                        break
                    }
                }
        }
    }
}
