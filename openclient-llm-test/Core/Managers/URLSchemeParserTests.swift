//
//  URLSchemeParserTests.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import XCTest
@testable import openclient_llm

@MainActor
final class URLSchemeParserTests: XCTestCase {
    // MARK: - chat?text=

    func test_parse_chatText_returnsAction() throws {
        let url = try XCTUnwrap(URL(string: "openclient://chat?text=Hello%20world"))
        let result = URLSchemeParser.parse(url)
        XCTAssertEqual(result, .chat(text: "Hello world", url: nil))
    }

    func test_parse_chatText_emptyText_returnsNil() throws {
        // Both query params missing → no action
        let url = try XCTUnwrap(URL(string: "openclient://chat"))
        let result = URLSchemeParser.parse(url)
        XCTAssertNil(result)
    }

    // MARK: - chat?url=

    func test_parse_chatURL_returnsAction() throws {
        let url = try XCTUnwrap(URL(string: "openclient://chat?url=https://example.com"))
        let result = URLSchemeParser.parse(url)
        XCTAssertEqual(result, .chat(text: nil, url: "https://example.com"))
    }

    func test_parse_chatTextAndURL_returnsAction() throws {
        let url = try XCTUnwrap(URL(string: "openclient://chat?text=Look&url=https://example.com"))
        let result = URLSchemeParser.parse(url)
        XCTAssertEqual(result, .chat(text: "Look", url: "https://example.com"))
    }

    // MARK: - conversation?id=

    func test_parse_conversation_validUUID_returnsAction() throws {
        let id = UUID()
        let url = try XCTUnwrap(URL(string: "openclient://conversation?id=\(id.uuidString)"))
        let result = URLSchemeParser.parse(url)
        XCTAssertEqual(result, .conversation(id: id))
    }

    func test_parse_conversation_invalidUUID_returnsNil() throws {
        let url = try XCTUnwrap(URL(string: "openclient://conversation?id=not-a-uuid"))
        let result = URLSchemeParser.parse(url)
        XCTAssertNil(result)
    }

    func test_parse_conversation_missingID_returnsNil() throws {
        let url = try XCTUnwrap(URL(string: "openclient://conversation"))
        let result = URLSchemeParser.parse(url)
        XCTAssertNil(result)
    }

    // MARK: - Unknown / Invalid

    func test_parse_unknownHost_returnsNil() throws {
        let url = try XCTUnwrap(URL(string: "openclient://unknown"))
        let result = URLSchemeParser.parse(url)
        XCTAssertNil(result)
    }

    func test_parse_shareHost_returnsNil() throws {
        // "share" is handled separately by ShareManager, not URLSchemeParser
        let url = try XCTUnwrap(URL(string: "openclient://share"))
        let result = URLSchemeParser.parse(url)
        XCTAssertNil(result)
    }

    func test_parse_wrongScheme_returnsNil() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let result = URLSchemeParser.parse(url)
        XCTAssertNil(result)
    }

    func test_parse_schemeCaseInsensitive() throws {
        let url = try XCTUnwrap(URL(string: "OpenClient://chat?text=Hi"))
        let result = URLSchemeParser.parse(url)
        XCTAssertEqual(result, .chat(text: "Hi", url: nil))
    }
}
