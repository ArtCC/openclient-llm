//
//  MockAttachmentMigrationUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockAttachmentMigrationUseCase: AttachmentMigrationUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var executeCallCount = 0

    // MARK: - Execute

    func execute() {
        executeCallCount += 1
    }
}
