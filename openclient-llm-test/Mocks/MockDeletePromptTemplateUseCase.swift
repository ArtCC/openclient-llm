//
//  MockDeletePromptTemplateUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockDeletePromptTemplateUseCase: DeletePromptTemplateUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var deletedIds: [UUID] = []
    var error: Error?

    // MARK: - Execute

    func execute(_ templateId: UUID) throws {
        if let error { throw error }
        deletedIds.append(templateId)
    }
}
