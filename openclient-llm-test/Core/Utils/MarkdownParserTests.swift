//
//  MarkdownParserTests.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 29/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class MarkdownParserTests: XCTestCase {
    // MARK: - Empty & Plain Text

    func test_parse_emptyString_returnsEmpty() {
        // Given
        let input = ""

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertTrue(blocks.isEmpty)
    }

    func test_parse_plainText_returnsSingleTextBlock() {
        // Given
        let input = "Hello, world!"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .text(let content) = blocks[0] else {
            XCTFail("Expected .text block"); return
        }
        XCTAssertEqual(content, "Hello, world!")
    }

    func test_parse_multilineText_returnsSingleTextBlock() {
        // Given
        let input = "Line one\nLine two\nLine three"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .text(let content) = blocks[0] else {
            XCTFail("Expected .text block"); return
        }
        XCTAssertTrue(content.contains("Line one"))
        XCTAssertTrue(content.contains("Line three"))
    }

    func test_parse_textWithEmptyLines_preservesContent() {
        // Given
        let input = "Paragraph one\n\nParagraph two"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .text(let content) = blocks[0] else {
            XCTFail("Expected .text block"); return
        }
        XCTAssertTrue(content.contains("Paragraph one"))
        XCTAssertTrue(content.contains("Paragraph two"))
    }

    // MARK: - Headings

    func test_parse_singleHeading_returnsHeadingBlock() {
        // Given
        let input = "# Hello"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .heading(let text, let level) = blocks[0] else {
            XCTFail("Expected .heading block"); return
        }
        XCTAssertEqual(text, "Hello")
        XCTAssertEqual(level, 1)
    }

    func test_parse_multipleHeadingLevels_returnsCorrectLevels() {
        // Given
        let input = "## H2\n### H3\n###### H6"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 3)
        guard case .heading(_, let level2) = blocks[0] else {
            XCTFail("Expected .heading block"); return
        }
        guard case .heading(_, let level3) = blocks[1] else {
            XCTFail("Expected .heading block"); return
        }
        guard case .heading(_, let level6) = blocks[2] else {
            XCTFail("Expected .heading block"); return
        }
        XCTAssertEqual(level2, 2)
        XCTAssertEqual(level3, 3)
        XCTAssertEqual(level6, 6)
    }

    func test_parse_headingWithTextBefore_appendsTextBlock() {
        // Given
        let input = "Intro text\n# Heading"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 2)
        guard case .text = blocks[0] else {
            XCTFail("Expected .text first"); return
        }
        guard case .heading = blocks[1] else {
            XCTFail("Expected .heading second"); return
        }
    }

    func test_parse_headingWithTextAfter_appendsTextBlock() {
        // Given
        let input = "# Heading\nBody text"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 2)
        guard case .heading = blocks[0] else {
            XCTFail("Expected .heading first"); return
        }
        guard case .text(let content) = blocks[1] else {
            XCTFail("Expected .text second"); return
        }
        XCTAssertEqual(content, "Body text")
    }

    // MARK: - Code Blocks

    func test_parse_fencedCodeBlock_returnsCodeBlock() {
        // Given
        let input = "```\nlet x = 1\n```"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .codeBlock(let code, let language) = blocks[0] else {
            XCTFail("Expected .codeBlock"); return
        }
        XCTAssertEqual(code, "let x = 1")
        XCTAssertNil(language)
    }

    func test_parse_fencedCodeBlock_withLanguage_extractsLanguage() {
        // Given
        let input = "```swift\nfunc hello() {}\n```"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .codeBlock(_, let language) = blocks[0] else {
            XCTFail("Expected .codeBlock"); return
        }
        XCTAssertEqual(language, "swift")
    }

    func test_parse_codeBlockWithSurroundingText_separatesCorrectly() {
        // Given
        let input = "Before\n```\ncode\n```\nAfter"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 3)
        guard case .text(let before) = blocks[0] else {
            XCTFail("Expected .text first"); return
        }
        guard case .codeBlock = blocks[1] else {
            XCTFail("Expected .codeBlock second"); return
        }
        guard case .text(let after) = blocks[2] else {
            XCTFail("Expected .text third"); return
        }
        XCTAssertEqual(before, "Before")
        XCTAssertEqual(after, "After")
    }

    // MARK: - Mixed Content

    func test_parse_complexMixedContent_parsesAllBlockTypes() {
        // Given
        let input = """
        # Introduction

        This is a paragraph with some text.

        > A notable quote

        - Bullet one
        - Bullet two

        1. Step one
        2. Step two

        ---

        ```swift
        let x = 42
        ```

        | Col A | Col B |
        | ----- | ----- |
        | Val 1 | Val 2 |

        Final thoughts.
        """

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 9)
    }

    // MARK: - Regression

    func test_parse_regression_existingBehavior_notBroken() {
        // Given
        let input = """
        This is **bold** and *italic* text with `code`.

        ```python
        print("hello")
        ```

        ## Section

        More text here.
        """

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 4)
        guard case .text = blocks[0] else {
            XCTFail("Expected .text first"); return
        }
        guard case .codeBlock(let code, let lang) = blocks[1] else {
            XCTFail("Expected .codeBlock second"); return
        }
        guard case .heading = blocks[2] else {
            XCTFail("Expected .heading third"); return
        }
        guard case .text = blocks[3] else {
            XCTFail("Expected .text fourth"); return
        }
        XCTAssertEqual(code, "print(\"hello\")")
        XCTAssertEqual(lang, "python")
    }
}
