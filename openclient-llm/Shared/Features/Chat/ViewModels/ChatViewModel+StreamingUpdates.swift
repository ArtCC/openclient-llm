//
//  ChatViewModel+StreamingUpdates.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 20/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum StreamingTextUpdate {
    case token(String)
    case reasoning(String)
}

struct StreamingUpdateBuffer {
    var assistantMessageId: UUID?
    var updates: [StreamingTextUpdate] = []
    var flushTask: Task<Void, Never>?
}

// MARK: - Streaming UI updates

extension ChatViewModel {
    @discardableResult
    func enqueueStreamingTextUpdate(_ update: StreamingTextUpdate, assistantMessageId: UUID) -> Bool {
        guard isActiveStream(assistantMessageId) else { return false }
        switch update {
        case .token(let text), .reasoning(let text):
            guard !text.isEmpty else { return false }
        }
        if streamingUpdateBuffer.assistantMessageId != assistantMessageId {
            resetStreamingTextUpdates()
            streamingUpdateBuffer.assistantMessageId = assistantMessageId
        }

        guard streamingUpdateBuffer.flushTask != nil else {
            applyStreamingTextUpdates([update], assistantMessageId: assistantMessageId)
            scheduleStreamingTextFlush(for: assistantMessageId)
            return true
        }
        streamingUpdateBuffer.updates.append(update)
        return false
    }

    @discardableResult
    func flushStreamingTextUpdates(for assistantMessageId: UUID) -> Bool {
        let updates = takeStreamingTextUpdates(for: assistantMessageId)
        guard !updates.isEmpty else { return false }
        applyStreamingTextUpdates(updates, assistantMessageId: assistantMessageId)
        return true
    }

    func takeStreamingTextUpdates(for assistantMessageId: UUID) -> [StreamingTextUpdate] {
        guard streamingUpdateBuffer.assistantMessageId == assistantMessageId else { return [] }
        streamingUpdateBuffer.flushTask?.cancel()
        streamingUpdateBuffer.flushTask = nil
        let updates = streamingUpdateBuffer.updates
        streamingUpdateBuffer.updates = []
        return updates
    }

    func resetStreamingTextUpdates() {
        streamingUpdateBuffer.flushTask?.cancel()
        streamingUpdateBuffer = StreamingUpdateBuffer()
    }

    func applyStreamingTextUpdates(
        _ updates: [StreamingTextUpdate],
        assistantMessageId: UUID
    ) {
        guard case .loaded(var loadedState) = state else { return }
        applyStreamingTextUpdates(updates, to: &loadedState, assistantMessageId: assistantMessageId)
        state = .loaded(loadedState)
    }

    func applyStreamingTextUpdates(
        _ updates: [StreamingTextUpdate],
        to loadedState: inout LoadedState,
        assistantMessageId: UUID
    ) {
        guard !updates.isEmpty,
              let index = loadedState.messages.firstIndex(where: { $0.id == assistantMessageId }) else { return }
        applyStreamingTextUpdates(updates, to: &loadedState.messages[index])
        loadedState.streamingRevision += 1
    }

    func applyStreamingTextUpdates(_ updates: [StreamingTextUpdate], to message: inout ChatMessage) {
        for update in updates {
            switch update {
            case .token(let text):
                message.content += text
            case .reasoning(let text):
                message.reasoningContent = (message.reasoningContent ?? "") + text
            }
        }
    }
}

// MARK: - Private

private extension ChatViewModel {
    func scheduleStreamingTextFlush(for assistantMessageId: UUID) {
        streamingUpdateBuffer.flushTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  let self,
                  self.streamingUpdateBuffer.assistantMessageId == assistantMessageId else { return }
            self.streamingUpdateBuffer.flushTask = nil
            let updates = self.streamingUpdateBuffer.updates
            self.streamingUpdateBuffer.updates = []
            guard !updates.isEmpty else { return }
            self.applyStreamingTextUpdates(updates, assistantMessageId: assistantMessageId)
            self.scheduleStreamingTextFlush(for: assistantMessageId)
        }
    }
}
