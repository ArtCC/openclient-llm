//
//  MockPlayAudioUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

@MainActor
final class MockPlayAudioUseCase: PlayAudioUseCaseProtocol {
    // MARK: - Properties

    var playCalled = false
    var stopCalled = false

    // MARK: - PlayAudioUseCaseProtocol

    func play(data: Data, messageId: UUID) async {
        playCalled = true
    }

    func stop() {
        stopCalled = true
    }
}
