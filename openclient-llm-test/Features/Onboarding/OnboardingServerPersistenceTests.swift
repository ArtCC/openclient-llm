//
//  OnboardingServerPersistenceTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class OnboardingServerPersistenceTests: XCTestCase {
    func test_send_startChattingTapped_securePersistenceFails_doesNotCompleteOnboarding() {
        // Given
        let saveConfiguration = MockSaveServerConfigurationUseCase()
        saveConfiguration.result = false
        let completeOnboarding = MockCompleteOnboardingUseCase()
        let sut = OnboardingViewModel(
            state: .loaded(.init(
                currentStep: .allSet,
                serverURL: "https://example.com",
                apiKey: "key"
            )),
            completeOnboardingUseCase: completeOnboarding,
            saveServerConfigurationUseCase: saveConfiguration,
            testServerConnectionUseCase: MockTestServerConnectionUseCase(),
            checkLiteLLMHealthUseCase: MockCheckLiteLLMHealthUseCase()
        )
        var didComplete = false
        sut.onComplete = { didComplete = true }

        // When
        sut.send(.startChattingTapped)
        sut.send(.startChattingTapped)

        // Then
        XCTAssertFalse(completeOnboarding.executeCalled)
        XCTAssertFalse(didComplete)
        guard case .loaded(let state) = sut.state,
              case .failure = state.connectionStatus else {
            XCTFail("Expected a persistence failure")
            return
        }
        XCTAssertEqual(state.persistenceFailureCount, 2)
    }
}
