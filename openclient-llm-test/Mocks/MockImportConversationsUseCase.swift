//
//  MockImportConversationsUseCase.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockImportConversationsUseCase: ImportConversationsUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result = Result<ImportConversationsResult, Error>.success(
        ImportConversationsResult(
            importedConversationCount: 0,
            restoredAttachmentCount: 0,
            skippedAttachmentCount: 0
        )
    )
    var importedData: [Data] = []

    // MARK: - Execute

    func execute(_ data: Data) async throws -> ImportConversationsResult {
        importedData.append(data)
        return try result.get()
    }
}
