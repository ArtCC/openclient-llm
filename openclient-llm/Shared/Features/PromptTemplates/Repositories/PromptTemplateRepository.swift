//
//  PromptTemplateRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

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
    func loadAll() throws -> [PromptTemplate]
    func save(_ template: PromptTemplate) throws
    func delete(_ templateId: UUID) throws
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
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager()
    ) {
        self.fileManager = fileManager
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directoryURL = documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true)
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
    }

    // MARK: - Public

    func loadAll() throws -> [PromptTemplate] {
        LogManager.debug("loadAll prompt templates")
        try ensureDirectoryExists()

        var localCustom = try loadCustomTemplates()

        if settingsManager.getIsCloudSyncEnabled() {
            let cloudTemplates = (try? cloudSyncManager.loadTemplatesFromCloud()) ?? []
            let cloudIds = cloudSyncManager.allCloudTemplateIds()

            localCustom = mergeTemplates(local: localCustom, cloud: cloudTemplates, cloudIds: cloudIds)

            if cloudIds != nil {
                let mergedIds = Set(localCustom.map(\.id))
                cleanupLocalFiles(keeping: mergedIds)
            }

            for template in localCustom {
                try saveLocal(template)
            }
        }

        let all = builtIns() + localCustom.sorted { $0.createdAt < $1.createdAt }
        LogManager.success("loadAll returned \(all.count) prompt templates")
        return all
    }

    func save(_ template: PromptTemplate) throws {
        LogManager.debug("save prompt template id=\(template.id) title='\(template.title)'")
        guard !template.isBuiltIn else { return }
        try ensureDirectoryExists()
        try saveLocal(template)

        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.syncTemplatesToCloud([template])
        }

        LogManager.success("saved prompt template id=\(template.id)")
    }

    func delete(_ templateId: UUID) throws {
        LogManager.debug("delete prompt template id=\(templateId)")
        let fileURL = directoryURL.appendingPathComponent("\(templateId.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
        LogManager.success("deleted prompt template id=\(templateId)")

        if settingsManager.getIsCloudSyncEnabled() {
            try? cloudSyncManager.deleteTemplateFromCloud(templateId)
        }
    }
}

// MARK: - Private

private extension PromptTemplateRepository {
    func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func loadCustomTemplates() throws -> [PromptTemplate] {
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
                return try? decoder.decode(PromptTemplate.self, from: data)
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

    func mergeTemplates(
        local: [PromptTemplate],
        cloud: [PromptTemplate],
        cloudIds: Set<UUID>?
    ) -> [PromptTemplate] {
        var merged: [UUID: PromptTemplate] = [:]

        for template in local {
            if let cloudIds {
                guard cloudIds.contains(template.id) else { continue }
            }
            merged[template.id] = template
        }

        for cloudTemplate in cloud {
            // Cloud wins on conflict (most recently created custom template takes precedence)
            merged[cloudTemplate.id] = cloudTemplate
        }

        return Array(merged.values)
    }

    func cleanupLocalFiles(keeping ids: Set<UUID>) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for url in fileURLs where url.pathExtension == "json" {
            if let uuid = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
               !ids.contains(uuid) {
                try? fileManager.removeItem(at: url)
                LogManager.debug("Cleaned up local template file: \(uuid)")
            }
        }
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
