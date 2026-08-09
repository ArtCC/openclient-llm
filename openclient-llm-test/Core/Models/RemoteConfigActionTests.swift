//
//  RemoteConfigActionTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class RemoteConfigActionTests: XCTestCase {
    func test_decode_feedbackValue_returnsFeedbackAction() throws {
        // Given
        let data = Data("\"feedback\"".utf8)

        // When
        let action = try JSONDecoder().decode(RemoteConfig.Action.self, from: data)

        // Then
        XCTAssertEqual(action, .feedback)
    }

    func test_decode_tipValue_returnsTipAction() throws {
        // Given
        let data = Data("\"tip\"".utf8)

        // When
        let action = try JSONDecoder().decode(RemoteConfig.Action.self, from: data)

        // Then
        XCTAssertEqual(action, .tip)
    }
}
