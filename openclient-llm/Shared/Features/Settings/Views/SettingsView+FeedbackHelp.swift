//
//  SettingsView+FeedbackHelp.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - Feedback & Help

extension SettingsView {
    func feedbackSection(isShowingVotice: Binding<Bool>) -> some View {
        Section {
            Button {
                requestAppReview()
            } label: {
                Label(String(localized: "Rate the App"), systemImage: "star")
            }
            .buttonStyle(.plain)

            Button {
                isShowingVotice.wrappedValue = true
            } label: {
                Label(String(localized: "Suggest Features"), systemImage: "lightbulb")
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "Feedback"))
        }
    }

    func helpSection(isPresented: Binding<Bool>) -> some View {
        Section {
            Button {
                isPresented.wrappedValue = true
            } label: {
                Label(String(localized: "Help"), systemImage: "questionmark.circle")
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "Support"))
        }
    }
}
