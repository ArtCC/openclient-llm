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
#if os(macOS)
            macOSBody
#else
            iOSBody
#endif
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }

    // MARK: - iOS

    var iOSBody: some View {
        Group {
            switch viewModel.state {
            case .loading:
                AppSplashView(showsLoadingIndicator: true)
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
    }

    // MARK: - macOS

    var macOSBody: some View {
        ZStack {
            HomeView()
#if os(macOS)
                .toolbar(viewModel.state == .loading ? .hidden : .automatic, for: .windowToolbar)
#endif

            if viewModel.state == .loading {
                AppSplashView(showsLoadingIndicator: true, backgroundMaterial: .ultraThickMaterial)
                    .transition(.opacity)
            }

            if viewModel.state == .onboarding {
                OnboardingView {
                    viewModel.send(.onboardingCompleted)
                }
                .transition(.opacity)
            }
        }
        .animation(.smooth, value: viewModel.state)
    }
}

// MARK: - Private

private extension LaunchView {}

#Preview("Onboarding not completed") {
    LaunchView()
}
