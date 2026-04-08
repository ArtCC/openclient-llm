//
//  SettingsView+WebDestination.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - WebDestination

extension SettingsView {
    enum WebDestination: Identifiable {
        case privacyPolicy
        case termsOfUse
        case authorGitHub

        // MARK: - Properties

        var id: String {
            switch self {
            case .privacyPolicy: "privacy"
            case .termsOfUse: "terms"
            case .authorGitHub: "author"
            }
        }

        var title: String {
            switch self {
            case .privacyPolicy: String(localized: "Privacy Policy")
            case .termsOfUse: String(localized: "Terms of Use")
            case .authorGitHub: String(localized: "GitHub Profile")
            }
        }

        var url: URL? {
            switch self {
            case .privacyPolicy:
                Constants.URLs.privacyPolicy
            case .termsOfUse:
                Constants.URLs.termsOfUse
            case .authorGitHub:
                Constants.URLs.authorGitHub
            }
        }
    }
}
