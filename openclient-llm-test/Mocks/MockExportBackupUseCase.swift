//
//  MockExportBackupUseCase.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 13/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockExportBackupUseCase: ExportBackupUseCaseProtocol, @unchecked Sendable {
    // MARK: - Properties

    var result: Result<Data, Error> = .success(Data())
    var executeCallCount = 0

    // MARK: - Execute

    func execute() throws -> Data {
        executeCallCount += 1
        return try result.get()
    }
}
