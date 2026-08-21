//
//  RenderedMarkdownTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 21/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class RenderedMarkdownTests: XCTestCase {
    func test_renderConcurrently_plainText_preservesBlocksAndCharacters() async throws {
        // Given
        let source = "Plain multiline text\nwith Unicode: áéí 🙂"

        // When
        let result = await MarkdownParser.renderConcurrently(source)
        let rendered = try XCTUnwrap(result)

        // Then
        XCTAssertEqual(rendered.blocks, MarkdownParser.parse(source))
        XCTAssertEqual(String(rendered.attributedString(for: source).characters), source)
    }

    func test_renderConcurrently_inlineMarkdown_matchesFoundationRendering() async throws {
        // Given
        let source = "**Bold**, *italic*, `code`, and [link](https://example.com)"
        let expected = try AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )

        // When
        let result = await MarkdownParser.renderConcurrently(source)
        let rendered = try XCTUnwrap(result)

        // Then
        XCTAssertEqual(rendered.attributedString(for: source), expected)
    }

    func test_renderConcurrently_structuredBlocks_cachesEveryInlineSource() async throws {
        // Given
        let source = """
        > Quote with **bold**
        - Bullet with *italic*
        1. Numbered with `code`
        - [ ] Pending task

        | Header | Value |
        | --- | --- |
        | Name | **OpenClient** |
        """

        // When
        let result = await MarkdownParser.renderConcurrently(source)
        let rendered = try XCTUnwrap(result)

        // Then
        let expectedSources = [
            "Quote with **bold**",
            "Bullet with *italic*",
            "Numbered with `code`",
            "Pending task",
            "Header",
            "Value",
            "Name",
            "**OpenClient**"
        ]
        for expectedSource in expectedSources {
            XCTAssertNotNil(rendered.inlineContent[expectedSource])
        }
    }

    func test_renderConcurrently_cancelledTask_returnsNil() async {
        // Given
        let task = Task {
            await MarkdownParser.renderConcurrently("Cancelled **content**")
        }

        // When
        task.cancel()
        let rendered = await task.value

        // Then
        XCTAssertNil(rendered)
    }

    func test_attributedString_missingCache_returnsPlainText() {
        // Given
        let rendered = RenderedMarkdown.empty

        // When
        let attributed = rendered.attributedString(for: "Uncached **source**")

        // Then
        XCTAssertEqual(String(attributed.characters), "Uncached **source**")
    }
}
