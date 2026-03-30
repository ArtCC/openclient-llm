//
//  LaunchView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//

import SwiftUI

struct LaunchView: View {
    // MARK: - Properties

    @State private var viewModel = LaunchViewModel()

    // MARK: - View

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .onboarding:
                // TODO: Replace with OnboardingView when implemented
                Text(String(localized: "Onboarding"))
            case .home:
                // TODO: Replace with HomeView when implemented
                Text(String(localized: "Home"))
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension LaunchView {}

#Preview("Onboarding not completed") {
    LaunchView()
}
