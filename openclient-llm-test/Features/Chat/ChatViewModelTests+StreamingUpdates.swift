//
//  ChatViewModelTests+StreamingUpdates.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 20/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Streaming UI updates

@MainActor
extension ChatViewModelTests {
    func test_enqueueStreamingTextUpdate_burst_buffersUpdatesAfterFirstPublication() {
        // Given
        let assistantId = prepareActiveStream()

        // When
        sut.enqueueStreamingTextUpdate(.token("First"), assistantMessageId: assistantId)
        sut.enqueueStreamingTextUpdate(.token(" second"), assistantMessageId: assistantId)
        sut.enqueueStreamingTextUpdate(.reasoning("Thinking"), assistantMessageId: assistantId)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.first?.content, "First")
        XCTAssertNil(loadedState.messages.first?.reasoningContent)
        XCTAssertEqual(sut.streamingUpdateBuffer.updates.count, 2)
    }

    func test_flushStreamingTextUpdates_interleavedUpdates_preservesContent() {
        // Given
        let assistantId = prepareActiveStream()
        sut.enqueueStreamingTextUpdate(.token("First"), assistantMessageId: assistantId)
        sut.enqueueStreamingTextUpdate(.reasoning("Think"), assistantMessageId: assistantId)
        sut.enqueueStreamingTextUpdate(.token(" second"), assistantMessageId: assistantId)
        sut.enqueueStreamingTextUpdate(.reasoning(" again"), assistantMessageId: assistantId)

        // When
        sut.flushStreamingTextUpdates(for: assistantId)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.first?.content, "First second")
        XCTAssertEqual(loadedState.messages.first?.reasoningContent, "Think again")
        XCTAssertEqual(loadedState.streamingRevision, 2)
        XCTAssertTrue(sut.streamingUpdateBuffer.updates.isEmpty)
    }

    func test_enqueueStreamingTextUpdate_emptyReasoning_ignoresUpdate() {
        // Given
        let assistantId = prepareActiveStream()
        sut.enqueueStreamingTextUpdate(.token("Answer"), assistantMessageId: assistantId)

        // When
        let didPublish = sut.enqueueStreamingTextUpdate(.reasoning(""), assistantMessageId: assistantId)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(didPublish)
        XCTAssertNil(loadedState.messages.first?.reasoningContent)
        XCTAssertTrue(sut.streamingUpdateBuffer.updates.isEmpty)
    }

    func test_enqueueStreamingTextUpdate_largeBurst_remainsBufferedUntilScheduledFlush() {
        // Given
        let assistantId = prepareActiveStream()
        sut.enqueueStreamingTextUpdate(.token("First"), assistantMessageId: assistantId)
        let bufferedText = String(repeating: "a", count: 1_024)

        // When
        let didPublish = sut.enqueueStreamingTextUpdate(.token(bufferedText), assistantMessageId: assistantId)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertFalse(didPublish)
        XCTAssertEqual(loadedState.messages.first?.content, "First")
        XCTAssertEqual(sut.streamingUpdateBuffer.updates.count, 1)
    }

    func test_cancelActiveStreaming_withBufferedText_flushesPartialResponse() {
        // Given
        let assistantId = prepareActiveStream()
        sut.enqueueStreamingTextUpdate(.token("First"), assistantMessageId: assistantId)
        sut.enqueueStreamingTextUpdate(.token(" second"), assistantMessageId: assistantId)

        // When
        sut.cancelActiveStreaming(shouldPersist: false)

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.first?.content, "First second")
        XCTAssertFalse(loadedState.isStreaming)
        XCTAssertNil(sut.streamingUpdateBuffer.assistantMessageId)
    }

    func test_enqueueStreamingTextUpdate_staleAssistant_doesNotMutateCurrentStream() {
        // Given
        let assistantId = prepareActiveStream()

        // When
        sut.enqueueStreamingTextUpdate(.token("Ignored"), assistantMessageId: UUID())

        // Then
        guard case .loaded(let loadedState) = sut.state else {
            XCTFail("Expected loaded state")
            return
        }
        XCTAssertEqual(loadedState.messages.first?.id, assistantId)
        XCTAssertEqual(loadedState.messages.first?.content, "")
        XCTAssertNil(sut.streamingUpdateBuffer.assistantMessageId)
    }

    private func prepareActiveStream() -> UUID {
        let assistantId = UUID()
        var loadedState = ChatViewModel.LoadedState()
        loadedState.messages = [ChatMessage(id: assistantId, role: .assistant, content: "")]
        loadedState.isStreaming = true
        sut.state = .loaded(loadedState)
        sut.activeAssistantMessageId = assistantId
        return assistantId
    }
}
