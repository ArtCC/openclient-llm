//
//  MCPToolAuthorizationRequestTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MCPToolAuthorizationRequestTests: XCTestCase {
    func test_formattedArguments_bidirectionalControl_escapesControlForDisplay() {
        // Given
        let request = MCPToolAuthorizationRequest(
            id: UUID(),
            toolCallId: "call",
            toolName: "tool",
            arguments: "{\"path\":\"safe\u{202E}txt.exe\"}",
            metadata: MCPToolAuthorizationMetadata(
                toolId: "tool-id",
                displayName: "tool",
                serverName: "server",
                toolDescription: nil,
                permissionKey: "permission-key",
                permission: .ask
            )
        )

        // When
        let displayedArguments = request.formattedArguments

        // Then
        XCTAssertTrue(displayedArguments.contains(#"\u{202E}"#))
        XCTAssertFalse(displayedArguments.contains("\u{202E}"))
    }
}
