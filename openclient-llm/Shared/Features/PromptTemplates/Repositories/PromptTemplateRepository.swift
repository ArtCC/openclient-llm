//
//  PromptTemplateRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import CryptoKit
import Foundation

// Stable UUIDs for built-in templates — never change; used to identify them across launches
private enum BuiltInTemplateID {
    static let epoch = Date(timeIntervalSince1970: 0)
    static let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
    static let id3 = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
    static let id4 = UUID(uuidString: "00000000-0000-0000-0000-000000000004") ?? UUID()
    static let id5 = UUID(uuidString: "00000000-0000-0000-0000-000000000005") ?? UUID()
    static let id6 = UUID(uuidString: "00000000-0000-0000-0000-000000000006") ?? UUID()
}

protocol PromptTemplateRepositoryProtocol: Sendable {
    func loadAll() async throws -> [PromptTemplate]
    func save(_ template: PromptTemplate) async throws
    func delete(_ templateId: UUID) async throws
}

struct PromptTemplateRepository: PromptTemplateRepositoryProtocol {
    // MARK: - Properties

    private let fileManager: FileManager
    private let directoryURL: URL
    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol

    // MARK: - Init

    init(
        fileManager: FileManager = .default,
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directoryURL = directoryURL
            ?? documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
    }

    // MARK: - Public

    func loadAll() async throws -> [PromptTemplate] {
        LogManager.debug("loadAll prompt templates")
        try ensureDirectoryExists()

        var deletionMarkers = try loadDeletionMarkers()
        let localTemplates = try loadCustomTemplates()
        var mergedTemplates = localTemplates.filter { shouldKeep($0.template, markers: deletionMarkers) }

        if settingsManager.getIsCloudSyncEnabled() {
            try await retryCloudDeletions(deletionMarkers)
            let snapshot = try await cloudSyncManager.loadTemplatesFromCloud()
            deletionMarkers = mergeDeletionMarkers(local: deletionMarkers, cloud: snapshot.deletionMarkers)
            try saveDeletionMarkers(deletionMarkers)
            mergedTemplates = try mergeTemplates(
                local: localTemplates,
                cloud: storedCloudTemplates(snapshot),
                markers: deletionMarkers
            )
            try persistLocalOutput(mergedTemplates)
            try await cloudSyncManager.syncTemplatesToCloud(mergedTemplates.map(\.template))
            for storedTemplate in mergedTemplates where shouldSupersedeMarker(
                storedTemplate.template,
                markers: deletionMarkers
            ) {
                try removeDeletionMarker(for: storedTemplate.template.id)
            }
        } else {
            try persistLocalOutput(mergedTemplates)
        }

        let customTemplates = mergedTemplates.map(\.template).sorted { $0.createdAt < $1.createdAt }
        let all = builtIns() + customTemplates
        LogManager.success("loadAll returned \(all.count) prompt templates")
        return all
    }

    func save(_ template: PromptTemplate) async throws {
        LogManager.debug("save prompt template id=\(template.id) title='\(template.title)'")
        guard !template.isBuiltIn else { return }
        try ensureDirectoryExists()
        let revisedTemplate = templateWithCurrentRevision(template)
        try saveLocal(revisedTemplate)

        if settingsManager.getIsCloudSyncEnabled() {
            try await retryCloudDeletions(try loadDeletionMarkers())
            try await cloudSyncManager.syncTemplatesToCloud([revisedTemplate])
        }
        try removeDeletionMarker(for: revisedTemplate.id)

        LogManager.success("saved prompt template id=\(revisedTemplate.id)")
    }

    func delete(_ templateId: UUID) async throws {
        LogManager.debug("delete prompt template id=\(templateId)")
        let fileURL = directoryURL.appendingPathComponent("\(templateId.uuidString).json")
        let localRevision = try? decoder().decode(
            PromptTemplate.self,
            from: Data(contentsOf: fileURL)
        ).updatedAt
        let markerRevision = try loadDeletionMarkers()[templateId]?.deletedAt
        let deletionFloor = max(localRevision ?? .distantPast, markerRevision ?? .distantPast)
        let deletedAt = nextRevision(after: deletionFloor)
        try saveDeletionMarker(CloudDeletionMarker(id: templateId, deletedAt: deletedAt))
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        LogManager.success("deleted prompt template id=\(templateId)")

        if settingsManager.getIsCloudSyncEnabled() {
            try await cloudSyncManager.deleteTemplateFromCloud(templateId, deletedAt: deletedAt)
        }
    }
}

// MARK: - Private

private extension PromptTemplateRepository {
    struct StoredTemplate {
        let template: PromptTemplate
        let data: Data
    }

    var deletionDirectoryURL: URL {
        directoryURL.appendingPathComponent(".DeletionMetadata", isDirectory: true)
    }

    var recoveryDirectoryURL: URL {
        directoryURL.deletingLastPathComponent().appendingPathComponent("PromptTemplateRecovery", isDirectory: true)
    }

    func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func loadCustomTemplates() throws -> [StoredTemplate] {
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                guard let template = try? decoder.decode(PromptTemplate.self, from: data),
                      UUID(uuidString: url.deletingPathExtension().lastPathComponent) == template.id,
                      !template.isBuiltIn else { return nil }
                return StoredTemplate(template: template, data: data)
            }
    }

    func saveLocal(_ template: PromptTemplate) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(template)
        let fileURL = directoryURL.appendingPathComponent("\(template.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
    }

    func loadDeletionMarkers() throws -> [UUID: CloudDeletionMarker] {
        guard fileManager.fileExists(atPath: deletionDirectoryURL.path) else { return [:] }
        let urls = try fileManager.contentsOfDirectory(at: deletionDirectoryURL, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try Dictionary(uniqueKeysWithValues: urls.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            let marker = try decoder.decode(CloudDeletionMarker.self, from: Data(contentsOf: url))
            return (marker.id, marker)
        })
    }

    func saveDeletionMarker(_ marker: CloudDeletionMarker) throws {
        try fileManager.createDirectory(at: deletionDirectoryURL, withIntermediateDirectories: true)
        let url = deletionDirectoryURL.appendingPathComponent("\(marker.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let existing = try? decoder().decode(CloudDeletionMarker.self, from: Data(contentsOf: url)),
           existing.deletedAt >= marker.deletedAt {
            return
        }
        try encoder.encode(marker).write(to: url, options: .atomic)
    }

    func saveDeletionMarkers(_ markers: [UUID: CloudDeletionMarker]) throws {
        for marker in markers.values {
            try saveDeletionMarker(marker)
        }
    }

    func removeDeletionMarker(for id: UUID) throws {
        let url = deletionDirectoryURL.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func retryCloudDeletions(_ markers: [UUID: CloudDeletionMarker]) async throws {
        for marker in markers.values {
            try await cloudSyncManager.deleteTemplateFromCloud(marker.id, deletedAt: marker.deletedAt)
        }
    }

    func mergeTemplates(
        local: [StoredTemplate],
        cloud: [StoredTemplate],
        markers: [UUID: CloudDeletionMarker]
    ) throws -> [StoredTemplate] {
        let localById = Dictionary(uniqueKeysWithValues: local.map { ($0.template.id, $0) })
        let cloudById = Dictionary(uniqueKeysWithValues: cloud.map { ($0.template.id, $0) })
        let ids = Set(localById.keys).union(cloudById.keys)
        return try ids.compactMap { id in
            let localCandidate = localById[id].flatMap {
                shouldKeep($0.template, markers: markers) ? $0 : nil
            }
            let cloudCandidate = cloudById[id].flatMap {
                shouldKeep($0.template, markers: markers) ? $0 : nil
            }
            guard let localCandidate, let cloudCandidate else {
                return localCandidate ?? cloudCandidate
            }
            guard localCandidate.data != cloudCandidate.data else { return localCandidate }
            let winner = preferredTemplate(local: localCandidate, cloud: cloudCandidate)
            try preserveForRecovery(winner.data == localCandidate.data ? cloudCandidate : localCandidate)
            return winner
        }
    }

    func preferredTemplate(local: StoredTemplate, cloud: StoredTemplate) -> StoredTemplate {
        if local.template.updatedAt == cloud.template.updatedAt {
            return cloud.data.lexicographicallyPrecedes(local.data) ? local : cloud
        }
        return local.template.updatedAt > cloud.template.updatedAt ? local : cloud
    }

    func storedCloudTemplates(_ snapshot: PromptTemplateCloudSnapshot) -> [StoredTemplate] {
        snapshot.templates.compactMap { template in
            guard !template.isBuiltIn, let data = snapshot.templateData[template.id] else { return nil }
            return StoredTemplate(template: template, data: data)
        }
    }

    func mergeDeletionMarkers(
        local: [UUID: CloudDeletionMarker],
        cloud: [UUID: CloudDeletionMarker]
    ) -> [UUID: CloudDeletionMarker] {
        cloud.reduce(into: local) { result, entry in
            if result[entry.key]?.deletedAt ?? .distantPast < entry.value.deletedAt {
                result[entry.key] = entry.value
            }
        }
    }

    func shouldKeep(_ template: PromptTemplate, markers: [UUID: CloudDeletionMarker]) -> Bool {
        guard let marker = markers[template.id] else { return true }
        return template.updatedAt > marker.deletedAt
    }

    func shouldSupersedeMarker(_ template: PromptTemplate, markers: [UUID: CloudDeletionMarker]) -> Bool {
        guard let marker = markers[template.id] else { return false }
        return template.updatedAt > marker.deletedAt
    }

    func persistLocalOutput(_ templates: [StoredTemplate]) throws {
        let ids = Set(templates.map(\.template.id))
        for storedTemplate in templates {
            try saveLocal(storedTemplate.template)
        }
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        for url in urls where url.pathExtension == "json" {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  !ids.contains(id) else { continue }
            try fileManager.removeItem(at: url)
        }
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

    func templateWithCurrentRevision(_ template: PromptTemplate) -> PromptTemplate {
        PromptTemplate(
            id: template.id,
            title: template.title,
            content: template.content,
            isBuiltIn: template.isBuiltIn,
            createdAt: template.createdAt,
            updatedAt: max(template.updatedAt, Date())
        )
    }

    func nextRevision(after revision: Date) -> Date {
        max(Date(), revision.addingTimeInterval(1))
    }

    func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
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
