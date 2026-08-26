//
//  AppIcon.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum AppIcon: String, CaseIterable, Identifiable {
    case defaultIcon = "Default"
    case midnight = "Midnight"
    case mono = "Mono"
    case ocean = "Ocean"
    case terminal = "Terminal"
    case arctic = "Arctic"
    case aurora = "Aurora"
    case berry = "Berry"
    case sunset = "Sunset"
    case violet = "Violet"
    case honeydew = "Honeydew"
    case lavender = "Lavender"
    case mars = "Mars"
    case sakura = "Sakura"
    case solar = "Solar"
    case blueprint = "Blueprint"
    case copper = "Copper"
    case holo = "Holo"
    case retro = "Retro"
    case ultraviolet = "Ultraviolet"

    enum Category: CaseIterable, Identifiable {
        case openClient
        case colors
        case bright
        case special

        var id: Self { self }

        var localizedName: String {
            switch self {
            case .openClient:
                String(localized: "OpenClient")
            case .colors:
                String(localized: "Colors")
            case .bright:
                String(localized: "Bright")
            case .special:
                String(localized: "Special")
            }
        }
    }

    var id: Self { self }

    var alternateIconName: String? {
        self == .defaultIcon ? nil : rawValue
    }

    var category: Category {
        switch self {
        case .defaultIcon, .midnight, .mono, .ocean, .terminal:
            .openClient
        case .arctic, .aurora, .berry, .sunset, .violet:
            .colors
        case .honeydew, .lavender, .mars, .sakura, .solar:
            .bright
        case .blueprint, .copper, .holo, .retro, .ultraviolet:
            .special
        }
    }

    var localizedName: String {
        switch self {
        case .defaultIcon:
            String(localized: "Default")
        case .midnight:
            String(localized: "Midnight")
        case .mono:
            String(localized: "Mono")
        case .ocean:
            String(localized: "Ocean")
        case .terminal:
            String(localized: "Terminal")
        case .arctic:
            String(localized: "Arctic")
        case .aurora:
            String(localized: "Aurora")
        case .berry:
            String(localized: "Berry")
        case .sunset:
            String(localized: "Sunset")
        case .violet:
            String(localized: "Violet")
        case .honeydew:
            String(localized: "Honeydew")
        case .lavender:
            String(localized: "Lavender")
        case .mars:
            String(localized: "Mars")
        case .sakura:
            String(localized: "Sakura")
        case .solar:
            String(localized: "Solar")
        case .blueprint:
            String(localized: "Blueprint")
        case .copper:
            String(localized: "Copper")
        case .holo:
            String(localized: "Holo")
        case .retro:
            String(localized: "Retro")
        case .ultraviolet:
            String(localized: "Ultraviolet")
        }
    }

    init(alternateIconName: String?) {
        guard let alternateIconName, let icon = Self(rawValue: alternateIconName) else {
            self = .defaultIcon
            return
        }
        self = icon
    }

    static func icons(in category: Category) -> [AppIcon] {
        allCases.filter { $0.category == category }
    }
}
