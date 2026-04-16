//
//  MockGetMemoryContextUseCase.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

struct MockGetMemoryContextUseCase: GetMemoryContextUseCaseProtocol, Sendable {
    // MARK: - Properties

    var context: String = ""

    // MARK: - GetMemoryContextUseCaseProtocol

    func execute() -> String {
        context
    }
}
