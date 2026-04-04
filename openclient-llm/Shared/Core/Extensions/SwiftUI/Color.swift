//
//  Color.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension Color {
    /// App brand accent color, resolved directly from the asset catalog.
    /// Use this instead of `Color.accentColor` in custom UI elements to ensure
    /// consistent blue branding on macOS regardless of the user's system accent setting.
    static let appAccent = Color("AccentColor")
}
