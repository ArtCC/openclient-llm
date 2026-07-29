//
//  MarkdownParserTests+Blocks.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 29/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

// MARK: - Blockquotes

extension MarkdownParserTests {
    func test_parse_singleLineBlockquote_returnsBlockquote() {
        // Given
        let input = "> This is a quote"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .blockquote(let content) = blocks[0] else {
            XCTFail("Expected .blockquote"); return
        }
        XCTAssertEqual(content, "This is a quote")
    }

    func test_parse_multilineBlockquote_joinsLines() {
        // Given
        let input = "> Line one\n> Line two\n> Line three"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .blockquote(let content) = blocks[0] else {
            XCTFail("Expected .blockquote"); return
        }
        XCTAssertTrue(content.contains("Line one"))
        XCTAssertTrue(content.contains("Line three"))
    }

    func test_parse_blockquoteWithSurroundingText_separatesCorrectly() {
        // Given
        let input = "Intro\n> A quote\nOutro"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 3)
        guard case .text(let intro) = blocks[0] else {
            XCTFail("Expected .text first"); return
        }
        guard case .blockquote(let quote) = blocks[1] else {
            XCTFail("Expected .blockquote second"); return
        }
        guard case .text(let outro) = blocks[2] else {
            XCTFail("Expected .text third"); return
        }
        XCTAssertEqual(intro, "Intro")
        XCTAssertEqual(quote, "A quote")
        XCTAssertEqual(outro, "Outro")
    }
}

// MARK: - Horizontal Rules

extension MarkdownParserTests {
    func test_parse_horizontalRule_dashes_returnsHorizontalRule() {
        // Given
        let input = "---"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .horizontalRule = blocks[0] else {
            XCTFail("Expected .horizontalRule"); return
        }
    }

    func test_parse_horizontalRule_asterisks_returnsHorizontalRule() {
        // Given
        let input = "***"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .horizontalRule = blocks[0] else {
            XCTFail("Expected .horizontalRule"); return
        }
    }

    func test_parse_horizontalRule_underscores_returnsHorizontalRule() {
        // Given
        let input = "___"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .horizontalRule = blocks[0] else {
            XCTFail("Expected .horizontalRule"); return
        }
    }

    func test_parse_horizontalRule_withSpaces_returnsHorizontalRule() {
        // Given
        let input = "- - -"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .horizontalRule = blocks[0] else {
            XCTFail("Expected .horizontalRule"); return
        }
    }

    func test_parse_horizontalRule_betweenText_separatesCorrectly() {
        // Given
        let input = "Above\n---\nBelow"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 3)
        guard case .text(let above) = blocks[0] else {
            XCTFail("Expected .text first"); return
        }
        guard case .horizontalRule = blocks[1] else {
            XCTFail("Expected .horizontalRule second"); return
        }
        guard case .text(let below) = blocks[2] else {
            XCTFail("Expected .text third"); return
        }
        XCTAssertEqual(above, "Above")
        XCTAssertEqual(below, "Below")
    }
}

// MARK: - Unordered Lists

extension MarkdownParserTests {
    func test_parse_unorderedList_dash_returnsUnorderedList() {
        // Given
        let input = "- Item one\n- Item two\n- Item three"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .unorderedList(let items) = blocks[0] else {
            XCTFail("Expected .unorderedList"); return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].content, "Item one")
        XCTAssertEqual(items[1].content, "Item two")
    }

    func test_parse_unorderedList_asterisk_returnsUnorderedList() {
        // Given
        let input = "* First\n* Second"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .unorderedList(let items) = blocks[0] else {
            XCTFail("Expected .unorderedList"); return
        }
        XCTAssertEqual(items.count, 2)
    }

    func test_parse_unorderedList_plus_returnsUnorderedList() {
        // Given
        let input = "+ Alpha\n+ Beta\n+ Gamma"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .unorderedList(let items) = blocks[0] else {
            XCTFail("Expected .unorderedList"); return
        }
        XCTAssertEqual(items.count, 3)
    }

    func test_parse_unorderedList_nested_setsDepth() {
        // Given
        let input = "- Parent\n  - Child\n    - Grandchild"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .unorderedList(let items) = blocks[0] else {
            XCTFail("Expected .unorderedList"); return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].depth, 0)
        XCTAssertEqual(items[1].depth, 1)
        XCTAssertEqual(items[2].depth, 2)
    }

    func test_parse_unorderedList_withSurroundingText_separatesCorrectly() {
        // Given
        let input = "Intro\n- Item 1\n- Item 2\nOutro"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 3)
        guard case .text(let intro) = blocks[0] else {
            XCTFail("Expected .text first"); return
        }
        guard case .unorderedList = blocks[1] else {
            XCTFail("Expected .unorderedList second"); return
        }
        guard case .text(let outro) = blocks[2] else {
            XCTFail("Expected .text third"); return
        }
        XCTAssertEqual(intro, "Intro")
        XCTAssertEqual(outro, "Outro")
    }
}

// MARK: - Ordered Lists

extension MarkdownParserTests {
    func test_parse_orderedList_basic_returnsOrderedList() {
        // Given
        let input = "1. First\n2. Second\n3. Third"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .orderedList(let items) = blocks[0] else {
            XCTFail("Expected .orderedList"); return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].number, 1)
        XCTAssertEqual(items[0].content, "First")
        XCTAssertEqual(items[1].number, 2)
        XCTAssertEqual(items[2].number, 3)
        XCTAssertEqual(items[2].content, "Third")
    }

    func test_parse_orderedList_nested_setsDepth() {
        // Given
        let input = "1. Main\n  1. Sub A\n  2. Sub B\n2. Another"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .orderedList(let items) = blocks[0] else {
            XCTFail("Expected .orderedList"); return
        }
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].depth, 0)
        XCTAssertEqual(items[1].depth, 1)
        XCTAssertEqual(items[2].depth, 1)
        XCTAssertEqual(items[3].depth, 0)
    }

    func test_parse_orderedList_twoDigitNumbers_parsesCorrectly() {
        // Given
        let input = "10. Tenth\n11. Eleventh"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .orderedList(let items) = blocks[0] else {
            XCTFail("Expected .orderedList"); return
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].number, 10)
        XCTAssertEqual(items[1].number, 11)
    }
}

// MARK: - Tables

extension MarkdownParserTests {
    func test_parse_simpleTable_returnsTable() {
        // Given
        let input = "| Name | Age |\n| --- | --- |\n| Alice | 30 |\n| Bob | 25 |"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 1)
        guard case .table(let headers, let rows) = blocks[0] else {
            XCTFail("Expected .table"); return
        }
        XCTAssertEqual(headers, ["Name", "Age"])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["Alice", "30"])
        XCTAssertEqual(rows[1], ["Bob", "25"])
    }

    func test_parse_tableThreeColumns_parsesCorrectly() {
        // Given
        let input = "| ID | Name | Active |\n| -- | ---- | ------ |\n| 1 | Foo | Yes |"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .table(let headers, let rows) = blocks[0] else {
            XCTFail("Expected .table"); return
        }
        XCTAssertEqual(headers.count, 3)
        XCTAssertEqual(rows[0].count, 3)
        XCTAssertEqual(headers, ["ID", "Name", "Active"])
    }

    func test_parse_tableWithAlignmentMarkers_parsesCorrectly() {
        // Given
        let input = "| Left | Right | Center |\n| :--- | ---: | :---: |\n| A | B | C |"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .table(let headers, let rows) = blocks[0] else {
            XCTFail("Expected .table"); return
        }
        XCTAssertEqual(headers, ["Left", "Right", "Center"])
        XCTAssertEqual(rows[0], ["A", "B", "C"])
    }

    func test_parse_tableWithSurroundingText_separatesCorrectly() {
        // Given
        let input = "Intro\n| K | V |\n| - | - |\n| A | 1 |\nOutro"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        XCTAssertEqual(blocks.count, 3)
        guard case .text(let intro) = blocks[0] else {
            XCTFail("Expected .text first"); return
        }
        guard case .table = blocks[1] else {
            XCTFail("Expected .table second"); return
        }
        guard case .text(let outro) = blocks[2] else {
            XCTFail("Expected .text third"); return
        }
        XCTAssertEqual(intro, "Intro")
        XCTAssertEqual(outro, "Outro")
    }

    func test_parse_lineWithPipesButNoSeparator_notTreatedAsTable() {
        // Given
        let input = "This | is not | a table"

        // When
        let blocks = MarkdownParser.parse(input)

        // Then
        guard case .text = blocks[0] else {
            XCTFail("Expected .text"); return
        }
    }
}
