//
//  ConversationStorage+PendingDeletions.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Pending Deletions

extension ConversationStorage {
    func loadPendingDeletionIds() throws -> Set<UUID> {
        guard fileManager.fileExists(atPath: pendingDeletionsURL.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: pendingDeletionsURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        var result = Set<UUID>()
        for url in urls where url.pathExtension == "json" {
            let conversationId = try makeDecoder().decode(UUID.self, from: Data(contentsOf: url))
            guard UUID(uuidString: url.deletingPathExtension().lastPathComponent) == conversationId,
                  result.insert(conversationId).inserted else {
                throw CloudSyncError.invalidConversationData
            }
        }
        return result
    }

    func savePendingDeletion(conversationId: UUID) throws {
        try fileManager.createDirectory(at: pendingDeletionsURL, withIntermediateDirectories: true)
        let url = pendingDeletionURL(conversationId: conversationId)
        let data = try makeEncoder().encode(conversationId)
        try writeIfChanged(data, to: url)
        guard try makeDecoder().decode(UUID.self, from: Data(contentsOf: url)) == conversationId else {
            throw CloudSyncError.invalidConversationData
        }
    }

    func removePendingDeletion(conversationId: UUID) throws {
        let url = pendingDeletionURL(conversationId: conversationId)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
        if try fileManager.contentsOfDirectory(at: pendingDeletionsURL, includingPropertiesForKeys: nil).isEmpty {
            try fileManager.removeItem(at: pendingDeletionsURL)
        }
    }

    func removeAllPendingDeletions() throws {
        guard fileManager.fileExists(atPath: pendingDeletionsURL.path) else { return }
        try fileManager.removeItem(at: pendingDeletionsURL)
    }

    private func pendingDeletionURL(conversationId: UUID) -> URL {
        pendingDeletionsURL.appendingPathComponent("\(conversationId.uuidString).json")
    }
}
