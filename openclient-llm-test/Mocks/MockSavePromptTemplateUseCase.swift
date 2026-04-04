//
//  MockSavePromptTemplateUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockSavePromptTemplateUseCase: SavePromptTemplateUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var savedTemplates: [PromptTemplate] = []
    var error: Error?

    // MARK: - Execute

    func execute(_ template: PromptTemplate) throws {
        if let error { throw error }
        savedTemplates.append(template)
    }
}
