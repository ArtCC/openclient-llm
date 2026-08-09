//
//  MockAppReviewManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

@MainActor
final class MockAppReviewManager: AppReviewManagerProtocol {
    // MARK: - Properties

    private(set) var requestReviewCallCount = 0

    // MARK: - AppReviewManagerProtocol

    func requestReview() {
        requestReviewCallCount += 1
    }
}
