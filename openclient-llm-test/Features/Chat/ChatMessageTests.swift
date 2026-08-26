//
//  ChatMessageTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class ChatMessageTests: XCTestCase {
    func test_hasSameRequestContent_withNormalizedAttachment_returnsTrue() {
        // Given
        let messageId = UUID()
        let attachmentId = UUID()
        let transient = ChatMessage(
            id: messageId,
            role: .user,
            content: "Review this",
            attachments: [.init(
                id: attachmentId,
                type: .pdf,
                fileName: "document.pdf",
                mimeType: "application/pdf",
                fileRelativePath: "",
                transientData: Data("PDF".utf8)
            )]
        )
        let persisted = ChatMessage(
            id: messageId,
            role: .user,
            content: "Review this",
            attachments: [.init(
                id: attachmentId,
                type: .pdf,
                fileName: "document.pdf",
                mimeType: "application/pdf",
                fileRelativePath: "Attachments/conversation/document.pdf"
            )]
        )

        // When
        let result = transient.hasSameRequestContent(as: persisted)

        // Then
        XCTAssertTrue(result)
    }
}
