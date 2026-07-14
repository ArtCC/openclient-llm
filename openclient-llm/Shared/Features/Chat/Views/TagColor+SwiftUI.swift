//
//  TagColor+SwiftUI.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension TagColor {
    var displayColor: Color {
        switch self {
        case .red:
            .red
        case .orange:
            .orange
        case .yellow:
            .yellow
        case .green:
            .green
        case .mint:
            .mint
        case .teal:
            .teal
        case .cyan:
            .cyan
        case .blue:
            .blue
        case .indigo:
            .indigo
        case .purple:
            .purple
        }
    }
}
