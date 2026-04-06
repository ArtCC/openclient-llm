//
//  SceneDelegate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 06/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import UIKit

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    // MARK: - UIWindowSceneDelegate (Cold Launch)

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let item = connectionOptions.shortcutItem,
              let action = ShortcutAction(rawValue: item.type) else {
            return
        }

        ShortcutManager.shared.pendingAction = action
    }

    // MARK: - Quick Actions (Background Launch)

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let action = ShortcutAction(rawValue: shortcutItem.type) else {
            completionHandler(false)

            return
        }

        ShortcutManager.shared.pendingAction = action

        completionHandler(true)
    }
}
