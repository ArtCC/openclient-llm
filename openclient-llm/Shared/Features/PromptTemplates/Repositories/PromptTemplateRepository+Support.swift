//
//  PromptTemplateRepository+Support.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CryptoKit
import Foundation

// Stable UUIDs for built-in templates. These values identify them across launches.
private enum BuiltInTemplateID {
    static let epoch = Date(timeIntervalSince1970: 0)
    static let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
    static let id3 = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
    static let id4 = UUID(uuidString: "00000000-0000-0000-0000-000000000004") ?? UUID()
    static let id5 = UUID(uuidString: "00000000-0000-0000-0000-000000000005") ?? UUID()
    static let id6 = UUID(uuidString: "00000000-0000-0000-0000-000000000006") ?? UUID()
}

extension PromptTemplateRepository {
    struct StoredTemplate {
        let template: PromptTemplate
        let data: Data
    }

    var recoveryDirectoryURL: URL {
        directoryURL.deletingLastPathComponent().appendingPathComponent("PromptTemplateRecovery", isDirectory: true)
    }

    func preserveForRecovery(_ storedTemplate: StoredTemplate) throws {
        try fileManager.createDirectory(at: recoveryDirectoryURL, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: storedTemplate.data).prefix(8).map { String(format: "%02x", $0) }.joined()
        let url = recoveryDirectoryURL.appendingPathComponent("\(storedTemplate.template.id.uuidString)-\(digest).json")
        if let existing = try? Data(contentsOf: url), existing == storedTemplate.data { return }
        try storedTemplate.data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == storedTemplate.data else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func validateRawCloudSnapshot(_ snapshot: PromptTemplateCloudSnapshot) throws {
        guard snapshot.templateDirectoryExists || snapshot.templateDirectoryData.isEmpty,
              snapshot.tombstoneDirectoryExists || snapshot.tombstoneDirectoryData.isEmpty,
              Set(snapshot.templates.map(\.id)).count == snapshot.templates.count else {
            throw PromptTemplateRepositoryError.invalidCloudSnapshot
        }
        let rawTemplates: [UUID: PromptTemplate] = try decodeCloudDirectory(
            snapshot.templateDirectoryData,
            as: PromptTemplate.self,
            id: \.id
        )
        let markers: [UUID: CloudDeletionMarker] = try decodeCloudDirectory(
            snapshot.tombstoneDirectoryData,
            as: CloudDeletionMarker.self,
            id: \.id
        )
        let staleIDs: Set<UUID> = Set(rawTemplates.compactMap { element -> UUID? in
            let (id, template) = element
            guard let marker = markers[id], template.updatedAt <= marker.deletedAt else { return nil }
            return id
        })
        let eligibleTemplates = rawTemplates.filter { id, template in
            guard let marker = markers[id] else { return true }
            return template.updatedAt > marker.deletedAt
        }
        let eligibleData: [UUID: Data] = Dictionary(
            uniqueKeysWithValues: snapshot.templateDirectoryData.compactMap { element -> (UUID, Data)? in
            let (name, data) = element
            guard let id = UUID(uuidString: URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent),
                  eligibleTemplates[id] != nil else { return nil }
            return (id, data)
            }
        )
        guard rawTemplates == snapshot.rawTemplates,
              rawTemplates.values.allSatisfy({ !$0.isBuiltIn }),
              markers == snapshot.deletionMarkers,
              staleIDs == snapshot.staleTemplateIds,
              eligibleTemplates == Dictionary(uniqueKeysWithValues: snapshot.templates.map { ($0.id, $0) }),
              eligibleData == snapshot.templateData else {
            throw PromptTemplateRepositoryError.invalidCloudSnapshot
        }
    }

    func decodeCloudDirectory<Value: Decodable>(
        _ files: [String: Data],
        as type: Value.Type,
        id valueID: KeyPath<Value, UUID>
    ) throws -> [UUID: Value] {
        try Dictionary(uniqueKeysWithValues: files.map { name, data in
            let url = URL(fileURLWithPath: name)
            guard url.pathExtension == "json",
                  url.lastPathComponent == name,
                  let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  url.deletingPathExtension().lastPathComponent == id.uuidString else {
                throw PromptTemplateRepositoryError.invalidCloudSnapshot
            }
            let value = try decoder().decode(type, from: data)
            guard value[keyPath: valueID] == id else {
                throw PromptTemplateRepositoryError.invalidCloudSnapshot
            }
            return (id, value)
        })
    }

    func templateWithRevision(_ template: PromptTemplate, after revision: Date) -> PromptTemplate {
        PromptTemplate(
            id: template.id,
            title: template.title,
            content: template.content,
            isBuiltIn: template.isBuiltIn,
            createdAt: template.createdAt,
            updatedAt: nextRevision(after: revision)
        )
    }

    func nextRevision(after revision: Date) -> Date {
        let floor = max(Date().timeIntervalSince1970, revision.timeIntervalSince1970)
        return Date(timeIntervalSince1970: floor.rounded(.up) + 1)
    }

    func hasSameContent(_ lhs: PromptTemplate, _ rhs: PromptTemplate) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.content == rhs.content
            && lhs.isBuiltIn == rhs.isBuiltIn
            && lhs.createdAt == rhs.createdAt
    }

    func encoded<Value: Encodable>(_ value: Value) throws -> Data {
        try SyncJSONCoding.makeEncoder().encode(value)
    }

    func canonicalTemplate(_ template: PromptTemplate) throws -> PromptTemplate {
        try decoder().decode(PromptTemplate.self, from: encoded(template))
    }

    func decoder() -> JSONDecoder {
        SyncJSONCoding.makeDecoder()
    }

    func builtIns() -> [PromptTemplate] {
        let codingContent = String(localized: """
            You are an expert software engineer. Help with code, explain concepts clearly, \
            suggest best practices, and provide working code examples. \
            Always prefer readable and maintainable solutions.
            """)
        let translatorContent = String(localized: """
            You are a professional translator. Translate the user's text accurately while \
            preserving the original meaning, tone, and nuance. Identify the source language \
            automatically and ask for the target language if not specified.
            """)
        let summarizerContent = String(localized: """
            You are a concise summarizer. Extract the key points from any text the user provides. \
            Present summaries in clear bullet points. Focus on the most important information \
            and omit redundant details.
            """)
        let creativeContent = String(localized: """
            You are a creative writing assistant. Help craft engaging stories, characters, \
            dialogue, and descriptions. Offer imaginative ideas, vivid imagery, and compelling \
            narrative structure tailored to the user's style and genre.
            """)
        let analystContent = String(localized: """
            You are a data analysis expert. Help interpret data, identify patterns, suggest \
            visualisations, and explain statistical concepts. Provide clear and actionable \
            insights from any data the user shares.
            """)
        let emailContent = String(localized: """
            You are a professional email writing assistant. Draft clear, concise, and \
            appropriately toned emails based on the user's brief. Adapt the tone \
            (formal, casual, or persuasive) to the context described.
            """)

        return [
            PromptTemplate(id: BuiltInTemplateID.id1, title: String(localized: "Coding Assistant"),
                           content: codingContent, isBuiltIn: true, createdAt: BuiltInTemplateID.epoch),
            PromptTemplate(id: BuiltInTemplateID.id2, title: String(localized: "Translator"),
                           content: translatorContent, isBuiltIn: true, createdAt: BuiltInTemplateID.epoch),
            PromptTemplate(id: BuiltInTemplateID.id3, title: String(localized: "Summarizer"),
                           content: summarizerContent, isBuiltIn: true, createdAt: BuiltInTemplateID.epoch),
            PromptTemplate(id: BuiltInTemplateID.id4, title: String(localized: "Creative Writer"),
                           content: creativeContent, isBuiltIn: true, createdAt: BuiltInTemplateID.epoch),
            PromptTemplate(id: BuiltInTemplateID.id5, title: String(localized: "Data Analyst"),
                           content: analystContent, isBuiltIn: true, createdAt: BuiltInTemplateID.epoch),
            PromptTemplate(id: BuiltInTemplateID.id6, title: String(localized: "Email Composer"),
                           content: emailContent, isBuiltIn: true, createdAt: BuiltInTemplateID.epoch)
        ]
    }
}

enum PromptTemplateRepositoryError: LocalizedError {
    case invalidLocalTemplate
    case invalidLocalDeletionMarker
    case invalidCloudSnapshot

    var errorDescription: String? {
        switch self {
        case .invalidLocalTemplate:
            String(localized: "A local prompt template file is invalid and was preserved.")
        case .invalidLocalDeletionMarker:
            String(localized: "Local prompt template deletion metadata is invalid and was preserved.")
        case .invalidCloudSnapshot:
            String(localized: "Synchronized prompt template data is invalid.")
        }
    }
}
