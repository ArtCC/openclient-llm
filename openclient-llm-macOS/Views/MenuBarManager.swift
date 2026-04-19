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

    // MARK: - Public

    func setUp() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "message.circle.fill",
                accessibilityDescription: String(localized: "OpenClient")
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 380, height: 540)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarChatView { [weak self] in
                self?.popover?.performClose(nil)
                NSApplication.shared.activate()
                NSApplication.shared.windows
                    .first { !($0 is NSPanel) }?
                    .makeKeyAndOrderFront(nil)
            }
        )

        statusItem = item
        popover = pop
    }

    // MARK: - Private

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
