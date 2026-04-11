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

    // MARK: - View

    var body: some Scene {
        WindowGroup(id: "main") {
            LaunchView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            AppCommands()
        }
    }
}
