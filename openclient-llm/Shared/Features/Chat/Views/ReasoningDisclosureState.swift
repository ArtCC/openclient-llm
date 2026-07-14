//
//  ReasoningDisclosureState.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ReasoningDisclosureState: Equatable {
    // MARK: - Properties

    enum Phase: Equatable {
        case idle
        case reasoning
        case answering
    }

    private(set) var phase: Phase = .idle
    private(set) var isExpanded = false
    private(set) var userExpansion: Bool?

    // MARK: - Events

    mutating func viewAppeared(isStreaming: Bool, hasReasoning: Bool, hasAnswer: Bool) {
        userExpansion = nil

        guard isStreaming else {
            reset()
            return
        }
        if hasAnswer {
            phase = .answering
            isExpanded = false
        } else if hasReasoning {
            phase = .reasoning
            isExpanded = true
        } else {
            phase = .idle
            isExpanded = false
        }
    }

    mutating func reasoningReceived(isStreaming: Bool) {
        guard isStreaming else { return }
        if phase != .reasoning {
            userExpansion = nil
        }
        phase = .reasoning
        if userExpansion != false {
            isExpanded = true
        }
    }

    mutating func answerReceived(isStreaming: Bool) {
        guard isStreaming, phase != .answering else { return }
        phase = .answering
        if userExpansion != true {
            isExpanded = false
        }
    }

    mutating func toolStarted() {
        phase = .idle
        isExpanded = false
        userExpansion = nil
    }

    mutating func streamingEnded() {
        reset()
    }

    mutating func userToggledExpansion(_ isExpanded: Bool) {
        self.isExpanded = isExpanded
        userExpansion = isExpanded
    }

    // MARK: - Private

    private mutating func reset() {
        phase = .idle
        isExpanded = false
        userExpansion = nil
    }
}
