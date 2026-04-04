//
//  MockPromptTemplateRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockPromptTemplateRepository: PromptTemplateRepositoryProtocol, @unchecked Sendable {
    // MARK: - Properties

    var templates: [PromptTemplate] = []
    var loadError: Error?
    var saveError: Error?
    var deleteError: Error?
    var savedTemplates: [PromptTemplate] = []
    var deletedIds: [UUID] = []

    // MARK: - Public

    func loadAll() throws -> [PromptTemplate] {
        if let loadError { throw loadError }
        return templates
    }

    func save(_ template: PromptTemplate) throws {
        if let saveError { throw saveError }
        savedTemplates.append(template)
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
    }

    func delete(_ templateId: UUID) throws {
        if let deleteError { throw deleteError }
        deletedIds.append(templateId)
        templates.removeAll { $0.id == templateId }
    }
}
