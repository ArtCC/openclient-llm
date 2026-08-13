//
//  PromptTemplateRepository+LocalData.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension PromptTemplateRepository {
    var deletionDirectoryURL: URL {
        directoryURL.appendingPathComponent(".DeletionMetadata", isDirectory: true)
    }

    func deleteAllLocal() async throws {
        try await operationGate.perform {
            if fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.removeItem(at: directoryURL)
            }
            if fileManager.fileExists(atPath: recoveryDirectoryURL.path) {
                try fileManager.removeItem(at: recoveryDirectoryURL)
            }
            try ensureDirectoryExists()
        }
    }

    func purgeLocalData(through marker: CloudPurgeMarker) async throws {
        try await operationGate.perform {
            try ensureDirectoryExists()
            for stored in try loadCustomTemplates() where stored.template.updatedAt <= marker.deletedAt {
                let url = directoryURL.appendingPathComponent("\(stored.template.id.uuidString).json")
                try fileManager.removeItem(at: url)
            }
            for (id, deletionMarker) in try loadDeletionMarkers() where deletionMarker.deletedAt <= marker.deletedAt {
                let url = deletionDirectoryURL.appendingPathComponent("\(id.uuidString).json")
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
            }
            try purgeRecoveryTemplates(through: marker)
        }
    }

    func validateLocalReset() async throws {
        try await operationGate.perform {
            try ensureDirectoryExists()
            _ = try loadCustomTemplates()
            _ = try loadDeletionMarkers()
            guard fileManager.fileExists(atPath: recoveryDirectoryURL.path) else { return }
            for url in try recoveryTemplateURLs() {
                _ = try decoder().decode(PromptTemplate.self, from: Data(contentsOf: url))
            }
        }
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
        return try contents.filter { $0.pathExtension == "json" }.map { url in
            guard let fileID = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                throw PromptTemplateRepositoryError.invalidLocalTemplate
            }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw PromptTemplateRepositoryError.invalidLocalTemplate
            }
            let template: PromptTemplate
            do {
                template = try decoder().decode(PromptTemplate.self, from: data)
            } catch {
                throw PromptTemplateRepositoryError.invalidLocalTemplate
            }
            guard template.id == fileID, !template.isBuiltIn else {
                throw PromptTemplateRepositoryError.invalidLocalTemplate
            }
            return StoredTemplate(template: template, data: data)
        }
    }

    func saveLocal(_ template: PromptTemplate) throws {
        let data = try encoded(template)
        let fileURL = directoryURL.appendingPathComponent("\(template.id.uuidString).json")
        if let existing = try? Data(contentsOf: fileURL), existing == data { return }
        try data.write(to: fileURL, options: .atomic)
        guard try Data(contentsOf: fileURL) == data else { throw CocoaError(.fileWriteUnknown) }
    }

    func loadDeletionMarkers() throws -> [UUID: CloudDeletionMarker] {
        guard fileManager.fileExists(atPath: deletionDirectoryURL.path) else { return [:] }
        let urls = try fileManager.contentsOfDirectory(at: deletionDirectoryURL, includingPropertiesForKeys: nil)
        return try Dictionary(uniqueKeysWithValues: urls.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            guard let fileID = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                throw PromptTemplateRepositoryError.invalidLocalDeletionMarker
            }
            let marker: CloudDeletionMarker
            do {
                marker = try decoder().decode(CloudDeletionMarker.self, from: Data(contentsOf: url))
            } catch {
                throw PromptTemplateRepositoryError.invalidLocalDeletionMarker
            }
            guard marker.id == fileID else {
                throw PromptTemplateRepositoryError.invalidLocalDeletionMarker
            }
            return (marker.id, marker)
        })
    }

    func saveDeletionMarker(_ marker: CloudDeletionMarker) throws {
        try fileManager.createDirectory(at: deletionDirectoryURL, withIntermediateDirectories: true)
        let url = deletionDirectoryURL.appendingPathComponent("\(marker.id.uuidString).json")
        if fileManager.fileExists(atPath: url.path) {
            let existing: CloudDeletionMarker
            do {
                existing = try decoder().decode(CloudDeletionMarker.self, from: Data(contentsOf: url))
            } catch {
                throw PromptTemplateRepositoryError.invalidLocalDeletionMarker
            }
            guard existing.id == marker.id else {
                throw PromptTemplateRepositoryError.invalidLocalDeletionMarker
            }
            if existing.deletedAt >= marker.deletedAt { return }
        }
        let data = try encoded(marker)
        try data.write(to: url, options: .atomic)
        let writtenData = try Data(contentsOf: url)
        let writtenMarker = try decoder().decode(CloudDeletionMarker.self, from: writtenData)
        guard writtenData == data, writtenMarker.id == marker.id else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func saveDeletionMarkers(_ markers: [UUID: CloudDeletionMarker]) throws {
        for marker in markers.values {
            try saveDeletionMarker(marker)
        }
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

    private func purgeRecoveryTemplates(through marker: CloudPurgeMarker) throws {
        guard fileManager.fileExists(atPath: recoveryDirectoryURL.path) else { return }
        for url in try recoveryTemplateURLs() {
            let template = try decoder().decode(PromptTemplate.self, from: Data(contentsOf: url))
            if template.updatedAt <= marker.deletedAt {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func recoveryTemplateURLs() throws -> [URL] {
        try fileManager.contentsOfDirectory(at: recoveryDirectoryURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }
}
