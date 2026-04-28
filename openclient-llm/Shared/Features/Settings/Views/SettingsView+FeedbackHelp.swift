//
//  SettingsView+FeedbackHelp.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - Support

extension SettingsView {
    func supportSection() -> some View {
        Section {
            Button {
                isShowingTipJar = true
            } label: {
                Label(String(localized: "Buy Me a Coffee"), systemImage: "cup.and.saucer")
            }
            .buttonStyle(.plain)

            Button {
                requestAppReview()
            } label: {
                Label(String(localized: "Rate the App"), systemImage: "star")
            }
            .buttonStyle(.plain)

            Button {
                isShowingVotice = true
            } label: {
                Label(String(localized: "Suggest Features"), systemImage: "lightbulb")
            }
            .buttonStyle(.plain)

            Button {
                isShowingHelp = true
            } label: {
                Label(String(localized: "Help"), systemImage: "questionmark.circle")
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "Support"))
        }
    }
}
