//
//  LaunchView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
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
                OnboardingView {
                    withAnimation(.smooth) {
                        viewModel.send(.onboardingCompleted)
                    }
                }
            case .home:
                HomeView()
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
