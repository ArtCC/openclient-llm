//
//  AppDelegate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 06/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - UIApplication

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: ShortcutAction.newChat.rawValue,
                localizedTitle: String(localized: "New Chat"),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(type: .compose)
            ),
            UIApplicationShortcutItem(
                type: ShortcutAction.search.rawValue,
                localizedTitle: String(localized: "Search"),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(type: .search)
            )
        ]

        return true
    }

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self

        return config
    }
}
