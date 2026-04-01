//
//  LaunchViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class LaunchViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case onboardingCompleted
    }

    enum State: Equatable {
        case loading
        case onboarding
        case home
    }

    private(set) var state: State

    private let checkOnboardingUseCase: CheckOnboardingUseCaseProtocol
    private let resetAppDataUseCase: ResetAppDataUseCaseProtocol
    private let configureVoticeUseCase: ConfigureVoticeUseCaseProtocol

    // MARK: - Init

    init(
        state: State = .loading,
        checkOnboardingUseCase: CheckOnboardingUseCaseProtocol = CheckOnboardingUseCase(),
        resetAppDataUseCase: ResetAppDataUseCaseProtocol = ResetAppDataUseCase(),
        configureVoticeUseCase: ConfigureVoticeUseCaseProtocol = ConfigureVoticeUseCase()
    ) {
        self.state = state
        self.checkOnboardingUseCase = checkOnboardingUseCase
        self.resetAppDataUseCase = resetAppDataUseCase
        self.configureVoticeUseCase = configureVoticeUseCase
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            configureVotice()

            let isCompleted = checkOnboardingUseCase.execute()
            if !isCompleted {
                resetAppDataUseCase.execute()
            }
            state = isCompleted ? .home : .onboarding
        case .onboardingCompleted:
            state = .home
        }
    }

    // MARK: - Private functions

    func configureVotice() {
        do {
            try configureVoticeUseCase.execute(userIsPremium: false)
        } catch {
            LogManager.error("LaunchViewModel: configureVoticeUseCase: execute: error: \(error)")
        }
    }
}
