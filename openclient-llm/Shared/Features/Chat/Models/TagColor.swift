//
//  TagColor.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum TagColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TagColor(rawValue: rawValue) ?? .orange
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var localizedName: String {
        switch self {
        case .red:
            String(localized: "Red")
        case .orange:
            String(localized: "Orange")
        case .yellow:
            String(localized: "Yellow")
        case .green:
            String(localized: "Green")
        case .mint:
            String(localized: "Mint")
        case .teal:
            String(localized: "Teal")
        case .cyan:
            String(localized: "Cyan")
        case .blue:
            String(localized: "Blue")
        case .indigo:
            String(localized: "Indigo")
        case .purple:
            String(localized: "Purple")
        }
    }
}
