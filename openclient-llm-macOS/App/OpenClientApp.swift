//
//  OpenClientApp.swift
//  openclient-llm-macOS
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

@main
struct OpenClientApp: App {
    // MARK: - Properties

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Init

    init() {
        AppTips.configure()
    }

    // MARK: - View

    var body: some Scene {
        Window(String(localized: "OpenClient"), id: "main") {
            MainWindowContent(appDelegate: appDelegate)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            AppCommands()
        }
    }
}

// MARK: - MainWindowContent

private struct MainWindowContent: View {
    @Environment(\.openWindow) private var openWindow

    let appDelegate: AppDelegate

    var body: some View {
        LaunchView()
            .frame(minWidth: 800, minHeight: 600)
            .onAppear {
                appDelegate.setOpenMainWindowAction {
                    openWindow(id: "main")
                }
            }
            .onOpenURL { url in
                guard let action = URLSchemeParser.parse(url) else { return }
                URLSchemeManager.shared.pendingAction = action
            }
    }
}
