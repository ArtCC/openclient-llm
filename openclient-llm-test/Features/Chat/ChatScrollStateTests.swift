//
//  ChatScrollStateTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 21/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ChatScrollStateTests: XCTestCase {
    private let defaultSessionId = UUID()

    func test_update_initialConversationWithMessages_requestsBottomFollow() {
        // Given
        var sut = ChatScrollState()
        let snapshot = makeSnapshot(lastMessageId: UUID(), responseRevision: 0)

        // When
        let shouldScroll = sut.update(from: nil, to: snapshot)

        // Then
        XCTAssertTrue(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    func test_update_initialEmptyConversation_doesNotRequestScroll() {
        // Given
        var sut = ChatScrollState()
        let snapshot = makeSnapshot(lastMessageId: nil, responseRevision: 0)

        // When
        let shouldScroll = sut.update(from: nil, to: snapshot)

        // Then
        XCTAssertFalse(shouldScroll)
    }

    func test_update_streamedContentWithSameMessage_doesNotRequestAnotherScroll() {
        // Given
        var sut = ChatScrollState()
        let messageId = UUID()
        let snapshot = makeSnapshot(lastMessageId: messageId, responseRevision: 1)
        _ = sut.update(from: nil, to: snapshot)

        // When
        let shouldScroll = sut.update(from: snapshot, to: snapshot)

        // Then
        XCTAssertFalse(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    func test_update_streamedContentWhileFollowing_requestsBottomScroll() {
        // Given
        var sut = ChatScrollState()
        let messageId = UUID()
        let previous = makeSnapshot(lastMessageId: messageId, responseRevision: 1, streamingRevision: 1)
        _ = sut.update(from: nil, to: previous)

        // When
        let current = makeSnapshot(lastMessageId: messageId, responseRevision: 1, streamingRevision: 2)
        let shouldScroll = sut.update(from: previous, to: current)

        // Then
        XCTAssertTrue(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    func test_userScrollBegan_duringStreaming_detachesBottomFollow() {
        // Given
        var sut = ChatScrollState()
        _ = sut.update(from: nil, to: makeSnapshot(lastMessageId: UUID(), responseRevision: 1))

        // When
        sut.userScrollBegan()

        // Then
        XCTAssertFalse(sut.isFollowingBottom)
        XCTAssertTrue(sut.isUserScrolling)
    }

    func test_update_streamedContentAfterUserScroll_remainsDetached() {
        // Given
        var sut = ChatScrollState()
        let messageId = UUID()
        let previous = makeSnapshot(lastMessageId: messageId, responseRevision: 1, streamingRevision: 1)
        _ = sut.update(from: nil, to: previous)
        sut.userScrollBegan()
        sut.userScrollEnded()

        // When
        let current = makeSnapshot(lastMessageId: messageId, responseRevision: 1, streamingRevision: 2)
        let shouldScroll = sut.update(from: previous, to: current)

        // Then
        XCTAssertFalse(shouldScroll)
        XCTAssertFalse(sut.isFollowingBottom)
        XCTAssertFalse(sut.isUserScrolling)
    }

    func test_update_newResponseAfterDetaching_resumesBottomFollow() {
        // Given
        var sut = ChatScrollState()
        let previous = makeSnapshot(lastMessageId: UUID(), responseRevision: 0)
        _ = sut.update(from: nil, to: previous)
        sut.userScrollBegan()
        sut.userScrollEnded()

        // When
        let shouldScroll = sut.update(
            from: previous,
            to: makeSnapshot(lastMessageId: UUID(), responseRevision: 1)
        )

        // Then
        XCTAssertTrue(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    func test_update_newResponseAndStreamedContentAfterDetaching_resumesBottomFollow() {
        // Given
        var sut = ChatScrollState()
        let previous = makeSnapshot(lastMessageId: UUID(), responseRevision: 1, streamingRevision: 1)
        _ = sut.update(from: nil, to: previous)
        sut.userScrollBegan()

        // When
        let shouldScroll = sut.update(
            from: previous,
            to: makeSnapshot(lastMessageId: UUID(), responseRevision: 2, streamingRevision: 2)
        )

        // Then
        XCTAssertTrue(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    func test_update_streamCompletionWhileFollowing_requestsBottomScroll() {
        // Given
        var sut = ChatScrollState()
        let previous = makeSnapshot(lastMessageId: UUID(), responseRevision: 1, isStreaming: true)
        _ = sut.update(from: nil, to: previous)

        // When
        let shouldScroll = sut.update(
            from: previous,
            to: makeSnapshot(lastMessageId: UUID(), responseRevision: 1, isStreaming: false)
        )

        // Then
        XCTAssertTrue(shouldScroll)
    }

    func test_update_attachmentWhileFollowing_requestsBottomScroll() {
        // Given
        var sut = ChatScrollState()
        let previous = makeSnapshot(lastMessageId: UUID(), responseRevision: 1)
        _ = sut.update(from: nil, to: previous)

        // When
        let shouldScroll = sut.update(
            from: previous,
            to: makeSnapshot(lastMessageId: UUID(), responseRevision: 1, attachmentCount: 1)
        )

        // Then
        XCTAssertTrue(shouldScroll)
    }

    func test_update_followUpDuringStreaming_requestsOneBottomFollow() {
        // Given
        var sut = ChatScrollState()
        let previous = makeSnapshot(lastMessageId: UUID(), responseRevision: 1)
        _ = sut.update(from: nil, to: previous)

        // When
        let shouldScroll = sut.update(
            from: previous,
            to: makeSnapshot(lastMessageId: UUID(), responseRevision: 2)
        )

        // Then
        XCTAssertTrue(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    func test_detach_programmaticNavigation_staysDetached() {
        // Given
        var sut = ChatScrollState()

        // When
        sut.detach()

        // Then
        XCTAssertFalse(sut.isFollowingBottom)
        XCTAssertFalse(sut.isUserScrolling)
    }

    func test_followBottom_afterDetaching_resumesBottomFollow() {
        // Given
        var sut = ChatScrollState()
        sut.userScrollBegan()

        // When
        sut.followBottom()

        // Then
        XCTAssertTrue(sut.isFollowingBottom)
        XCTAssertFalse(sut.isUserScrolling)
    }

    func test_update_initialConversationAfterDetaching_resumesBottomFollow() {
        // Given
        var sut = ChatScrollState()
        sut.detach()

        // When
        let shouldScroll = sut.update(
            from: nil,
            to: makeSnapshot(lastMessageId: UUID(), responseRevision: 0)
        )

        // Then
        XCTAssertTrue(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    func test_update_newSessionWithMessages_requestsBottomFollow() {
        // Given
        var sut = ChatScrollState()
        let previous = makeSnapshot(lastMessageId: UUID(), responseRevision: 0)
        _ = sut.update(from: nil, to: previous)
        sut.userScrollBegan()
        let newSessionId = UUID()

        // When
        let shouldScroll = sut.update(
            from: previous,
            to: makeSnapshot(sessionId: newSessionId, lastMessageId: UUID(), responseRevision: 0)
        )

        // Then
        XCTAssertTrue(shouldScroll)
        XCTAssertTrue(sut.isFollowingBottom)
    }

    private func makeSnapshot(
        sessionId: UUID? = nil,
        lastMessageId: UUID?,
        responseRevision: Int,
        streamingRevision: Int = 0,
        isStreaming: Bool = false,
        attachmentCount: Int = 0
    ) -> ChatScrollState.Snapshot {
        ChatScrollState.Snapshot(
            sessionId: sessionId ?? defaultSessionId,
            lastMessageId: lastMessageId,
            responseRevision: responseRevision,
            streamingRevision: streamingRevision,
            isStreaming: isStreaming,
            attachmentCount: attachmentCount
        )
    }
}
