//
//  ConversationRebaser.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum ConversationRebaser {
    static func rebase(
        _ incoming: Conversation,
        base: Conversation,
        onto current: Conversation
    ) throws -> Conversation {
        var result = current
        rebaseConfiguration(incoming, base: base, result: &result)
        rebaseMetadata(incoming, base: base, result: &result)
        result.messages = try rebasedMessages(
            incoming.messages,
            base: base.messages,
            current: current.messages
        )
        return result
    }
}

// MARK: - Private

private extension ConversationRebaser {
    nonisolated struct MessageGraph {
        var edges: [UUID: Set<UUID>]
        var indegrees: [UUID: Int]
    }

    nonisolated static func rebaseConfiguration(
        _ incoming: Conversation,
        base: Conversation,
        result: inout Conversation
    ) {
        if incoming.title != base.title { result.title = incoming.title }
        if incoming.modelId != base.modelId { result.modelId = incoming.modelId }
        if incoming.systemPrompt != base.systemPrompt { result.systemPrompt = incoming.systemPrompt }
        if incoming.contextWindowTokens != base.contextWindowTokens {
            result.contextWindowTokens = incoming.contextWindowTokens
        }
        if incoming.contextSummary != base.contextSummary { result.contextSummary = incoming.contextSummary }
        if incoming.contextSummaryCursorMessageId != base.contextSummaryCursorMessageId {
            result.contextSummaryCursorMessageId = incoming.contextSummaryCursorMessageId
        }
        if incoming.modelParameters != base.modelParameters { result.modelParameters = incoming.modelParameters }
    }

    nonisolated static func rebaseMetadata(
        _ incoming: Conversation,
        base: Conversation,
        result: inout Conversation
    ) {
        if incoming.isPinned != base.isPinned { result.isPinned = incoming.isPinned }
        if incoming.tags != base.tags { result.tags = incoming.tags }
        if incoming.parentConversationId != base.parentConversationId {
            result.parentConversationId = incoming.parentConversationId
        }
        if incoming.branchedFromMessageId != base.branchedFromMessageId {
            result.branchedFromMessageId = incoming.branchedFromMessageId
        }
    }

    nonisolated static func rebasedMessages(
        _ incoming: [ChatMessage],
        base: [ChatMessage],
        current: [ChatMessage]
    ) throws -> [ChatMessage] {
        guard incoming != base else { return current }
        guard current != base else { return incoming }
        guard incoming != current else { return current }
        if messagesDifferOnlyByFavourite(incoming, base) {
            return applyingFavouriteChanges(from: incoming, base: base, to: current)
        }
        if messagesDifferOnlyByFavourite(current, base) {
            return applyingFavouriteChanges(from: current, base: base, to: incoming)
        }
        guard preservesBaseMessages(incoming, base: base),
              preservesBaseMessages(current, base: base) else {
            throw CloudSyncError.staleConversationRevision
        }
        return try mergeMessageSequences(incoming, current, base: base)
    }

    nonisolated static func preservesBaseMessages(_ candidate: [ChatMessage], base: [ChatMessage]) -> Bool {
        guard Set(candidate.map(\.id)).count == candidate.count else { return false }
        let baseById = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        let retainedBase = candidate.compactMap { message -> ChatMessage? in
            guard let baseMessage = baseById[message.id] else { return nil }
            return messagesDifferOnlyByFavourite([message], [baseMessage]) ? message : nil
        }
        return retainedBase.map(\.id) == base.map(\.id)
    }

    nonisolated static func mergeMessageSequences(
        _ first: [ChatMessage],
        _ second: [ChatMessage],
        base: [ChatMessage]
    ) throws -> [ChatMessage] {
        let messages = try mergedMessagesById(first, second, base: base)
        var graph = makeGraph(sequences: [first, second], ids: Set(messages.keys))
        var available = graph.indegrees.filter { $0.value == 0 }.map(\.key)
        var result: [ChatMessage] = []
        while let id = nextMessageId(from: &available, messages: messages) {
            guard let message = messages[id] else { throw CloudSyncError.invalidConversationData }
            result.append(message)
            for successor in graph.edges[id] ?? [] {
                graph.indegrees[successor, default: 0] -= 1
                if graph.indegrees[successor] == 0 { available.append(successor) }
            }
        }
        guard result.count == messages.count else { throw CloudSyncError.staleConversationRevision }
        return result
    }

    nonisolated static func mergedMessagesById(
        _ first: [ChatMessage],
        _ second: [ChatMessage],
        base: [ChatMessage]
    ) throws -> [UUID: ChatMessage] {
        let baseById = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        var result: [UUID: ChatMessage] = [:]
        for message in first + second {
            guard let existing = result[message.id] else {
                result[message.id] = message
                continue
            }
            result[message.id] = try mergedMessage(existing, message, base: baseById[message.id])
        }
        return result
    }

    nonisolated static func mergedMessage(
        _ first: ChatMessage,
        _ second: ChatMessage,
        base: ChatMessage?
    ) throws -> ChatMessage {
        var normalized = first
        normalized.isFavourite = second.isFavourite
        guard normalized == second else { throw CloudSyncError.staleConversationRevision }
        guard let base else {
            guard first.isFavourite == second.isFavourite else {
                throw CloudSyncError.staleConversationRevision
            }
            return first
        }
        let firstChanged = first.isFavourite != base.isFavourite
        let secondChanged = second.isFavourite != base.isFavourite
        if firstChanged { return first }
        if secondChanged { return second }
        return first
    }

    nonisolated static func makeGraph(sequences: [[ChatMessage]], ids: Set<UUID>) -> MessageGraph {
        var graph = MessageGraph(
            edges: Dictionary(uniqueKeysWithValues: ids.map { ($0, Set<UUID>()) }),
            indegrees: Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) })
        )
        for sequence in sequences {
            for (source, destination) in zip(sequence, sequence.dropFirst()) where source.id != destination.id {
                if graph.edges[source.id, default: []].insert(destination.id).inserted {
                    graph.indegrees[destination.id, default: 0] += 1
                }
            }
        }
        return graph
    }

    nonisolated static func nextMessageId(
        from available: inout [UUID],
        messages: [UUID: ChatMessage]
    ) -> UUID? {
        available.sort { lhs, rhs in
            guard let left = messages[lhs], let right = messages[rhs] else {
                return lhs.uuidString < rhs.uuidString
            }
            if left.timestamp == right.timestamp { return lhs.uuidString < rhs.uuidString }
            return left.timestamp < right.timestamp
        }
        return available.isEmpty ? nil : available.removeFirst()
    }

    nonisolated static func applyingFavouriteChanges(
        from source: [ChatMessage],
        base: [ChatMessage],
        to target: [ChatMessage]
    ) -> [ChatMessage] {
        let changes = Dictionary(uniqueKeysWithValues: zip(source, base).compactMap { source, base in
            source.isFavourite == base.isFavourite ? nil : (source.id, source.isFavourite)
        })
        return target.map { message in
            guard let isFavourite = changes[message.id] else { return message }
            var message = message
            message.isFavourite = isFavourite
            return message
        }
    }

    nonisolated static func messagesDifferOnlyByFavourite(_ lhs: [ChatMessage], _ rhs: [ChatMessage]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            var normalizedLeft = left
            normalizedLeft.isFavourite = right.isFavourite
            return normalizedLeft == right
        }
    }
}
