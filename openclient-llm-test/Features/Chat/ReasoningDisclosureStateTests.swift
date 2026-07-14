//
//  ReasoningDisclosureStateTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ReasoningDisclosureStateTests: XCTestCase {
    func test_viewAppeared_completedMessage_startsCollapsed() {
        // Given
        var sut = ReasoningDisclosureState()

        // When
        sut.viewAppeared(isStreaming: false, hasReasoning: true, hasAnswer: true)

        // Then
        XCTAssertFalse(sut.isExpanded)
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_reasoningReceived_activeStream_expandsReasoning() {
        // Given
        var sut = ReasoningDisclosureState()

        // When
        sut.reasoningReceived(isStreaming: true)

        // Then
        XCTAssertTrue(sut.isExpanded)
        XCTAssertEqual(sut.phase, .reasoning)
    }

    func test_reasoningReceived_afterUserCloses_remainsCollapsed() {
        // Given
        var sut = ReasoningDisclosureState()
        sut.reasoningReceived(isStreaming: true)
        sut.userToggledExpansion(false)

        // When
        sut.reasoningReceived(isStreaming: true)

        // Then
        XCTAssertFalse(sut.isExpanded)
    }

    func test_answerReceived_automaticExpansion_collapsesReasoning() {
        // Given
        var sut = ReasoningDisclosureState()
        sut.reasoningReceived(isStreaming: true)

        // When
        sut.answerReceived(isStreaming: true)

        // Then
        XCTAssertFalse(sut.isExpanded)
        XCTAssertEqual(sut.phase, .answering)
    }

    func test_answerReceived_afterUserOpens_remainsExpanded() {
        // Given
        var sut = ReasoningDisclosureState()
        sut.reasoningReceived(isStreaming: true)
        sut.userToggledExpansion(true)

        // When
        sut.answerReceived(isStreaming: true)

        // Then
        XCTAssertTrue(sut.isExpanded)
    }

    func test_toolStarted_activeReasoning_collapsesReasoning() {
        // Given
        var sut = ReasoningDisclosureState()
        sut.reasoningReceived(isStreaming: true)

        // When
        sut.toolStarted()

        // Then
        XCTAssertFalse(sut.isExpanded)
        XCTAssertEqual(sut.phase, .idle)
    }

    func test_reasoningReceived_afterTool_reopensReasoning() {
        // Given
        var sut = ReasoningDisclosureState()
        sut.reasoningReceived(isStreaming: true)
        sut.userToggledExpansion(false)
        sut.toolStarted()

        // When
        sut.reasoningReceived(isStreaming: true)

        // Then
        XCTAssertTrue(sut.isExpanded)
        XCTAssertEqual(sut.phase, .reasoning)
    }

    func test_streamingEnded_userOpenedReasoning_collapsesReasoning() {
        // Given
        var sut = ReasoningDisclosureState()
        sut.reasoningReceived(isStreaming: true)
        sut.userToggledExpansion(true)

        // When
        sut.streamingEnded()

        // Then
        XCTAssertFalse(sut.isExpanded)
        XCTAssertEqual(sut.phase, .idle)
    }
}
