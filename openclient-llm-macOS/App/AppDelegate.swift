//
//  AppDelegate.swift
//  openclient-llm-macOS
//
//  Created by Arturo Carretero Calvo on 10/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppKit

// MARK: - Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private let menuBarManager = MenuBarManager()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager.setUp()
    }
}
