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

    var characterCount: Int {
        switch self {
        case .token(let text), .reasoning(let text):
            text.count
        }
    }
}

struct StreamingUpdateBuffer {
    static let maximumBufferedCharacterCount = 96

    var assistantMessageId: UUID?
    var updates: [StreamingTextUpdate] = []
    var bufferedCharacterCount = 0
    var flushTask: Task<Void, Never>?
}

// MARK: - Streaming UI updates

extension ChatViewModel {
    @discardableResult
    func enqueueStreamingTextUpdate(_ update: StreamingTextUpdate, assistantMessageId: UUID) -> Bool {
        guard isActiveStream(assistantMessageId) else { return false }
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
        streamingUpdateBuffer.bufferedCharacterCount += update.characterCount
        guard streamingUpdateBuffer.bufferedCharacterCount >= StreamingUpdateBuffer.maximumBufferedCharacterCount else {
            return false
        }
        flushStreamingTextUpdates(for: assistantMessageId)
        scheduleStreamingTextFlush(for: assistantMessageId)
        return true
    }

    @discardableResult
    func flushStreamingTextUpdates(for assistantMessageId: UUID) -> Bool {
        guard streamingUpdateBuffer.assistantMessageId == assistantMessageId else { return false }
        streamingUpdateBuffer.flushTask?.cancel()
        streamingUpdateBuffer.flushTask = nil
        let updates = streamingUpdateBuffer.updates
        streamingUpdateBuffer.updates = []
        streamingUpdateBuffer.bufferedCharacterCount = 0
        guard !updates.isEmpty else { return false }
        applyStreamingTextUpdates(updates, assistantMessageId: assistantMessageId)
        return true
    }

    func resetStreamingTextUpdates() {
        streamingUpdateBuffer.flushTask?.cancel()
        streamingUpdateBuffer = StreamingUpdateBuffer()
    }

    func applyStreamingTextUpdates(
        _ updates: [StreamingTextUpdate],
        assistantMessageId: UUID
    ) {
        guard case .loaded(var loadedState) = state,
              let index = loadedState.messages.firstIndex(where: { $0.id == assistantMessageId }) else { return }
        for update in updates {
            switch update {
            case .token(let text):
                loadedState.messages[index].content += text
            case .reasoning(let text):
                loadedState.messages[index].reasoningContent =
                    (loadedState.messages[index].reasoningContent ?? "") + text
            }
        }
        state = .loaded(loadedState)
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
            guard let self,
                  self.streamingUpdateBuffer.assistantMessageId == assistantMessageId else { return }
            self.streamingUpdateBuffer.flushTask = nil
            let updates = self.streamingUpdateBuffer.updates
            self.streamingUpdateBuffer.updates = []
            self.streamingUpdateBuffer.bufferedCharacterCount = 0
            guard !updates.isEmpty else { return }
            self.applyStreamingTextUpdates(updates, assistantMessageId: assistantMessageId)
            self.scheduleStreamingTextFlush(for: assistantMessageId)
        }
    }
}
