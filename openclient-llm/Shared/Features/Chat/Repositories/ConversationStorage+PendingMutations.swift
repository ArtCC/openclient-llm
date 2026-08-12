//
//  ConversationStorage+PendingMutations.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Pending Mutations

extension ConversationStorage {
    func loadPendingMutationBases() throws -> [UUID: Conversation] {
        guard fileManager.fileExists(atPath: pendingMutationsURL.path) else { return [:] }
        let urls = try fileManager.contentsOfDirectory(
            at: pendingMutationsURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        var result: [UUID: Conversation] = [:]
        for url in urls where url.pathExtension == "json" {
            let data = try Data(contentsOf: url)
            let conversation = try makeDecoder().decode(Conversation.self, from: data)
            guard UUID(uuidString: url.deletingPathExtension().lastPathComponent) == conversation.id,
                  result[conversation.id] == nil else {
                throw CloudSyncError.invalidConversationData
            }
            result[conversation.id] = conversation
        }
        return result
    }

    func loadPendingMutationBase(conversationId: UUID) throws -> Conversation? {
        let url = pendingMutationURL(conversationId: conversationId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let conversation = try makeDecoder().decode(Conversation.self, from: Data(contentsOf: url))
        guard conversation.id == conversationId else {
            throw CloudSyncError.invalidConversationData
        }
        return conversation
    }

    func savePendingMutationBase(_ conversation: Conversation) throws {
        guard try loadPendingMutationBase(conversationId: conversation.id) == nil else { return }
        try fileManager.createDirectory(at: pendingMutationsURL, withIntermediateDirectories: true)
        try writeIfChanged(
            makeEncoder().encode(conversation),
            to: pendingMutationURL(conversationId: conversation.id)
        )
    }

    func replacePendingMutationBase(_ conversation: Conversation) throws {
        try fileManager.createDirectory(at: pendingMutationsURL, withIntermediateDirectories: true)
        try writeIfChanged(
            makeEncoder().encode(conversation),
            to: pendingMutationURL(conversationId: conversation.id)
        )
    }

    func removePendingMutation(conversationId: UUID) throws {
        let url = pendingMutationURL(conversationId: conversationId)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
        if try fileManager.contentsOfDirectory(at: pendingMutationsURL, includingPropertiesForKeys: nil).isEmpty {
            try fileManager.removeItem(at: pendingMutationsURL)
        }
    }

    func removeAllPendingMutations() throws {
        guard fileManager.fileExists(atPath: pendingMutationsURL.path) else { return }
        try fileManager.removeItem(at: pendingMutationsURL)
    }

    private func pendingMutationURL(conversationId: UUID) -> URL {
        pendingMutationsURL.appendingPathComponent("\(conversationId.uuidString).json")
    }
}
