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
    // MARK: - View

    var body: some Scene {
        WindowGroup(id: "main") {
            LaunchView()
        }
        .defaultSize(width: 1000, height: 700)
    }
}
