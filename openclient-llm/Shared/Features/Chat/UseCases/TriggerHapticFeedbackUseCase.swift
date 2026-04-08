//
//  TriggerHapticFeedbackUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 08/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol TriggerHapticFeedbackUseCaseProtocol: Sendable {
    func lightImpact()
}

struct TriggerHapticFeedbackUseCase: TriggerHapticFeedbackUseCaseProtocol {
    // MARK: - Execute

    func lightImpact() {
        HapticManager().lightImpact()
    }
}
