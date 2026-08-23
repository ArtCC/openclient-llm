//
//  ChatScrollState.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 21/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct ChatScrollState: Equatable {
    enum Mode: Equatable {
        case followingBottom
        case detached
    }

    struct Snapshot: Equatable {
        let sessionId: UUID
        let lastMessageId: UUID?
        let responseRevision: Int
        let streamingRevision: Int
        let isStreaming: Bool
        let attachmentCount: Int

        init(loadedState: ChatViewModel.LoadedState) {
            sessionId = loadedState.conversation?.id ?? loadedState.pendingSessionId
            lastMessageId = loadedState.messages.last?.id
            responseRevision = loadedState.responseRevision
            streamingRevision = loadedState.streamingRevision
            isStreaming = loadedState.isStreaming
            attachmentCount = loadedState.messages.last?.attachments.count ?? 0
        }

        init(
            sessionId: UUID,
            lastMessageId: UUID?,
            responseRevision: Int,
            streamingRevision: Int = 0,
            isStreaming: Bool = false,
            attachmentCount: Int = 0
        ) {
            self.sessionId = sessionId
            self.lastMessageId = lastMessageId
            self.responseRevision = responseRevision
            self.streamingRevision = streamingRevision
            self.isStreaming = isStreaming
            self.attachmentCount = attachmentCount
        }
    }

    private(set) var mode: Mode = .followingBottom
    private(set) var isUserScrolling = false

    var isFollowingBottom: Bool {
        mode == .followingBottom
    }

    mutating func update(from snapshot: Snapshot?, to newSnapshot: Snapshot) -> Bool {
        guard newSnapshot.lastMessageId != nil else { return false }
        guard let snapshot else {
            followBottom()
            return true
        }

        let changedSession = snapshot.sessionId != newSnapshot.sessionId
        let startedResponse = newSnapshot.responseRevision > snapshot.responseRevision
        if changedSession || startedResponse {
            followBottom()
            return true
        }
        let streamedContentChanged = newSnapshot.streamingRevision > snapshot.streamingRevision
        let completionChanged = newSnapshot.isStreaming != snapshot.isStreaming
        let attachmentsChanged = newSnapshot.attachmentCount != snapshot.attachmentCount
        return isFollowingBottom && (streamedContentChanged || completionChanged || attachmentsChanged)
    }

    mutating func userScrollBegan() {
        mode = .detached
        isUserScrolling = true
    }

    mutating func userScrollEnded() {
        isUserScrolling = false
    }

    mutating func followBottom() {
        mode = .followingBottom
        isUserScrolling = false
    }

    mutating func detach() {
        mode = .detached
        isUserScrolling = false
    }
}
