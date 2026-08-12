//
//  AppDelegate.swift
//  openclient-llm-macOS
//
//  Created by Arturo Carretero Calvo on 10/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppKit
import StoreKit

// MARK: - Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var transactionObserverTask: Task<Void, Never>?

    private let menuBarManager = MenuBarManager()
    private let conversationCloudObserver = ConversationCloudObserver.shared

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarManager.setUp()

        transactionObserverTask = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }

        conversationCloudObserver.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        conversationCloudObserver.start()
    }
}
