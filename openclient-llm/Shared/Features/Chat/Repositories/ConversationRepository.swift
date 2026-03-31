//
//  ConversationRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ConversationRepositoryProtocol: Sendable {
    func loadAll() throws -> [Conversation]
    func save(_ conversation: Conversation) throws
    func delete(_ conversationId: UUID) throws
    func deleteAll() throws
}

struct ConversationRepository: ConversationRepositoryProtocol {
    // MARK: - Properties

    private let fileManager: FileManager
    private let directoryURL: URL

    // MARK: - Init

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directoryURL = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
    }

    // MARK: - Public

    func loadAll() throws -> [Conversation] {
        try ensureDirectoryExists()

        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var conversations: [Conversation] = []
        for url in fileURLs where url.pathExtension == "json" {
            let data = try Data(contentsOf: url)
            let conversation = try decoder.decode(Conversation.self, from: data)
            conversations.append(conversation)
        }

        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ conversation: Conversation) throws {
        try ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(conversation)
        let fileURL = directoryURL.appendingPathComponent("\(conversation.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
    }

    func delete(_ conversationId: UUID) throws {
        let fileURL = directoryURL.appendingPathComponent("\(conversationId.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
        try ensureDirectoryExists()
    }
}

// MARK: - Private

private extension ConversationRepository {
    func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
