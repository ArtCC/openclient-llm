//
//  MenuBarManager.swift
//  openclient-llm-macOS
//
//  Created by Arturo Carretero Calvo on 10/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - Manager

@MainActor
final class MenuBarManager: NSObject {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var serverConfigurationObserver: NSObjectProtocol?
    private var isAuthorizationPending = false
    private let settingsManager: SettingsManagerProtocol
    private var openMainWindow: (@MainActor () -> Void)?

    // MARK: - Init

    init(settingsManager: SettingsManagerProtocol = SettingsManager()) {
        self.settingsManager = settingsManager
        super.init()
    }

    // MARK: - Public

    func setUp() {
        guard serverConfigurationObserver == nil else { return }
        serverConfigurationObserver = NotificationCenter.default.addObserver(
            forName: .serverConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateAvailability()
            }
        }
        updateAvailability()
    }

    func setOpenMainWindowAction(_ action: @escaping @MainActor () -> Void) {
        openMainWindow = action
    }

    // MARK: - Private

    private func updateAvailability() {
        if settingsManager.hasValidServerConfiguration() {
            setUpStatusItem()
        } else {
            tearDownStatusItem()
        }
    }

    private func setUpStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "brain.head.profile",
                accessibilityDescription: String(localized: "OpenClient")
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 380, height: 540)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarChatView(
                onOpenInApp: { [weak self] conversation in
                    self?.openInApp(conversation: conversation)
                },
                onAuthorizationStateChanged: { [weak self, weak pop] isPending in
                    self?.isAuthorizationPending = isPending
                    pop?.behavior = isPending ? .applicationDefined : .transient
                }
            )
        )

        statusItem = item
        popover = pop
    }

    private func tearDownStatusItem() {
        popover?.close()
        popover = nil
        isAuthorizationPending = false
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func openInApp(conversation: Conversation?) {
        URLSchemeManager.shared.pendingResolvedConversation = conversation
        URLSchemeManager.shared.pendingAction = conversation.map { .conversation(id: $0.id) } ?? .newChat
        popover?.performClose(nil)

        NSApplication.shared.activate()
        if let mainWindow = NSApplication.shared.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            openMainWindow?()
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            guard !isAuthorizationPending else {
                NSSound.beep()
                return
            }
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
