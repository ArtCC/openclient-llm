//
//  URLSchemeParser.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - URLSchemeParser

/// Parses `openclient://` deep-link URLs into `URLSchemeAction` values.
/// Stateless — all methods are static.
enum URLSchemeParser {
    // MARK: - Public

    /// Returns a `URLSchemeAction` for the given URL, or `nil` if the URL is
    /// not a recognised `openclient://` deep link.
    static func parse(_ url: URL) -> URLSchemeAction? {
        guard url.scheme?.lowercased() == "openclient" else { return nil }

        switch url.host?.lowercased() {
        case "new-chat":
            return .newChat
        case "search":
            return .search
        case "chat":
            return parseChat(url)
        case "conversation":
            return parseConversation(url)
        default:
            return nil
        }
    }
}

// MARK: - Private

private extension URLSchemeParser {
    static func parseChat(_ url: URL) -> URLSchemeAction? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = components.queryItems ?? []
        let text = items.first(where: { $0.name == "text" })?.value
        let urlValue = items.first(where: { $0.name == "url" })?.value

        // Require at least one parameter
        guard text != nil || urlValue != nil else { return nil }
        return .chat(text: text, url: urlValue)
    }

    static func parseConversation(_ url: URL) -> URLSchemeAction? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: idString) else {
            return nil
        }
        return .conversation(id: id)
    }
}
