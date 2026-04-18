//
//  SceneDelegate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 06/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    // MARK: - UIWindowSceneDelegate (Cold Launch)

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let item = connectionOptions.shortcutItem,
           let action = ShortcutAction(rawValue: item.type) {
            ShortcutManager.shared.pendingAction = action
        }

        for context in connectionOptions.urlContexts {
            handle(url: context.url)
        }
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

    // MARK: - URL Scheme (Warm Launch)

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handle(url: context.url)
        }
    }
}

// MARK: - Private

private extension SceneDelegate {
    func handle(url: URL) {
        guard url.scheme == "openclient", url.host == "share" else { return }
        ShareManager.shared.hasPendingShare = true
    }
}
