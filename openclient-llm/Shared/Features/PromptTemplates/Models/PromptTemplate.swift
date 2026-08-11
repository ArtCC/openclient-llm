//
//  PromptTemplate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct PromptTemplate: Identifiable, Equatable, Sendable, Codable {
    // MARK: - Properties

    let id: UUID
    var title: String
    var content: String
    let isBuiltIn: Bool
    let createdAt: Date
    let updatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

nonisolated struct PromptTemplateCloudSnapshot: Sendable {
    let session: CloudSyncSession
    let templates: [PromptTemplate]
    let templateData: [UUID: Data]
    let rawTemplates: [UUID: PromptTemplate]
    let staleTemplateIds: Set<UUID>
    let deletionMarkers: [UUID: CloudDeletionMarker]
    let templateDirectoryData: [String: Data]
    let tombstoneDirectoryData: [String: Data]
    let templateDirectoryExists: Bool
    let tombstoneDirectoryExists: Bool
    var purgeMarker: CloudPurgeMarker?

    init(
        session: CloudSyncSession,
        templates: [PromptTemplate],
        templateData: [UUID: Data],
        rawTemplates: [UUID: PromptTemplate],
        staleTemplateIds: Set<UUID>,
        deletionMarkers: [UUID: CloudDeletionMarker],
        templateDirectoryData: [String: Data],
        tombstoneDirectoryData: [String: Data],
        templateDirectoryExists: Bool,
        tombstoneDirectoryExists: Bool,
        purgeMarker: CloudPurgeMarker? = nil
    ) {
        self.session = session
        self.templates = templates
        self.templateData = templateData
        self.rawTemplates = rawTemplates
        self.staleTemplateIds = staleTemplateIds
        self.deletionMarkers = deletionMarkers
        self.templateDirectoryData = templateDirectoryData
        self.tombstoneDirectoryData = tombstoneDirectoryData
        self.templateDirectoryExists = templateDirectoryExists
        self.tombstoneDirectoryExists = tombstoneDirectoryExists
        self.purgeMarker = purgeMarker
    }
}
