//
//  MarkdownParser.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - MessageBlock

enum MessageBlock: Equatable, Sendable {
    case text(String)
    case codeBlock(code: String, language: String?)
    case heading(text: String, level: Int)
    case blockquote(String)
    case unorderedList(items: [MarkdownListItem])
    case orderedList(items: [MarkdownOrderedListItem])
    case horizontalRule
    case table(headers: [String], rows: [[String]])
    case taskList(items: [MarkdownTaskItem])
    case image(alt: String, url: String)
}

// MARK: - MarkdownListItem

struct MarkdownListItem: Equatable, Sendable {
    let content: String
    let depth: Int
}

// MARK: - MarkdownOrderedListItem

struct MarkdownOrderedListItem: Equatable, Sendable {
    let number: Int
    let content: String
    let depth: Int
}

// MARK: - MarkdownTaskItem

struct MarkdownTaskItem: Equatable, Sendable {
    let isChecked: Bool
    let content: String
    let depth: Int
}

// MARK: - MarkdownParser

struct MarkdownParser: Sendable {
    // MARK: - Public

    static func parse(_ raw: String) -> [MessageBlock] {
        let lines = raw.components(separatedBy: "\n")

        var blocks: [MessageBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.hasPrefix("```") {
                let language = extractLanguage(from: line)
                var codeLines: [String] = []
                index += 1

                while index < lines.count {
                    if lines[index].hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(lines[index])
                    index += 1
                }

                let code = codeLines.joined(separator: "\n")
                blocks.append(.codeBlock(code: code, language: language))
            } else if isHorizontalRule(line) {
                blocks.append(.horizontalRule)
                index += 1
            } else if let table = tryParseTable(lines: lines, startIndex: index) {
                blocks.append(table)
                index = advancePastTable(lines: lines, startIndex: index)
            } else {
                parseMixedBlock(lines: lines, startIndex: &index, into: &blocks)
            }
        }

        return blocks
    }
}

// MARK: - Private: Mixed Block Parsing

private extension MarkdownParser {
    static func parseMixedBlock(lines: [String], startIndex: inout Int, into blocks: inout [MessageBlock]) {
        var accumulatedText: [String] = []

        while startIndex < lines.count && !lines[startIndex].hasPrefix("```") {
            let currentLine = lines[startIndex]

            if isHorizontalRule(currentLine) {
                flushText(&accumulatedText, into: &blocks)
                blocks.append(.horizontalRule)
                startIndex += 1
                continue
            } else if let image = parseImageLine(currentLine) {
                flushText(&accumulatedText, into: &blocks)
                blocks.append(image)
                startIndex += 1
                continue
            }

            if let table = tryParseTable(lines: lines, startIndex: startIndex) {
                flushText(&accumulatedText, into: &blocks)
                blocks.append(table)
                startIndex = advancePastTable(lines: lines, startIndex: startIndex)
                continue
            }

            if isBlockquoteLine(currentLine) {
                flushText(&accumulatedText, into: &blocks)
                startIndex = parseBlockquote(lines: lines, startIndex: startIndex, into: &blocks)
                continue
            } else if parseTaskListItem(currentLine) != nil {
                flushText(&accumulatedText, into: &blocks)
                startIndex = parseTaskList(lines: lines, startIndex: startIndex, into: &blocks)
                continue
            }

            if parseUnorderedListItem(currentLine) != nil {
                flushText(&accumulatedText, into: &blocks)
                startIndex = parseUnorderedList(lines: lines, startIndex: startIndex, into: &blocks)
                continue
            } else if parseOrderedListItem(currentLine) != nil {
                flushText(&accumulatedText, into: &blocks)
                startIndex = parseOrderedList(lines: lines, startIndex: startIndex, into: &blocks)
                continue
            }

            if let (level, headingText) = extractHeading(from: currentLine) {
                flushText(&accumulatedText, into: &blocks)
                blocks.append(.heading(text: headingText, level: level))
                startIndex += 1
                continue
            }

            accumulatedText.append(currentLine)
            startIndex += 1
        }

        flushText(&accumulatedText, into: &blocks)
    }

    static func flushText(_ text: inout [String], into blocks: inout [MessageBlock]) {
        let joined = text.joined(separator: "\n")
        if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.text(joined))
        }
        text.removeAll()
    }
}

// MARK: - Private: Blockquote

private extension MarkdownParser {
    static func isBlockquoteLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix(">")
    }

    static func stripBlockquotePrefix(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return line }
        let withoutAngle = String(trimmed.dropFirst()).trimmingPrefix(" ")
        return withoutAngle
    }

    static func parseBlockquote(lines: [String], startIndex: Int, into blocks: inout [MessageBlock]) -> Int {
        var index = startIndex
        var contentLines: [String] = []

        while index < lines.count && isBlockquoteLine(lines[index]) {
            contentLines.append(stripBlockquotePrefix(lines[index]))
            index += 1
        }

        let content = contentLines.joined(separator: "\n")
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.blockquote(content))
        }

        return index
    }
}

// MARK: - Private: Horizontal Rule

private extension MarkdownParser {
    static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }

        let firstChar = trimmed.first
        guard firstChar == "-" || firstChar == "*" || firstChar == "_" else { return false }

        let allSame = trimmed.allSatisfy { char in
            char == firstChar || char.isWhitespace
        }
        return allSame
    }
}

// MARK: - Private: List Item Match

private struct OrderedListItemMatch {
    let number: Int
    let depth: Int
    let content: String
}

// MARK: - Private: Image

private extension MarkdownParser {
    static func parseImageLine(_ line: String) -> MessageBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("![") else { return nil }

        let afterBang = trimmed.dropFirst(2)
        guard let altEnd = afterBang.firstIndex(of: "]") else { return nil }
        let alt = String(afterBang.prefix(upTo: altEnd))

        let afterAlt = afterBang[afterBang.index(after: altEnd)...]
        guard afterAlt.hasPrefix("(") else { return nil }

        let afterParen = afterAlt.dropFirst()
        guard let urlEnd = afterParen.firstIndex(of: ")") else { return nil }
        let url = String(afterParen.prefix(upTo: urlEnd)).trimmingCharacters(in: .whitespaces)

        // Only consume trailing characters that are part of the image syntax
        let remaining = afterParen[afterParen.index(after: urlEnd)...]
            .trimmingCharacters(in: .whitespaces)
        if !remaining.isEmpty {
            return nil
        }

        guard !url.isEmpty else { return nil }
        return .image(alt: alt, url: url)
    }
}

// MARK: - Private: Task Lists

private extension MarkdownParser {
    static func parseTaskListItem(_ line: String) -> MarkdownTaskItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let leadingSpaces = line.prefix(while: { $0 == " " }).count

        guard trimmed.count >= 5 else { return nil }

        let marker = String(trimmed.prefix(2))
        guard marker == "- " || marker == "* " || marker == "+ " else { return nil }

        let afterMarker = trimmed.dropFirst(2)
        let bracketStart = afterMarker.prefix(1)
        guard bracketStart == "[" else { return nil }

        let afterBracket = afterMarker.dropFirst()
        guard let closeBracket = afterBracket.firstIndex(of: "]") else { return nil }

        let checkChar = String(afterBracket.prefix(upTo: closeBracket))
        guard checkChar == " " || checkChar == "x" || checkChar == "X" else { return nil }

        let afterClose = afterBracket[afterBracket.index(after: closeBracket)...]
        guard afterClose.hasPrefix(" ") || afterClose.isEmpty else { return nil }

        let content = String(afterClose).trimmingPrefix(" ")
        return MarkdownTaskItem(
            isChecked: checkChar != " ",
            content: content,
            depth: leadingSpaces / 2
        )
    }

    static func parseTaskList(
        lines: [String],
        startIndex: Int,
        into blocks: inout [MessageBlock]
    ) -> Int {
        var index = startIndex
        var items: [MarkdownTaskItem] = []

        while index < lines.count {
            guard let item = parseTaskListItem(lines[index]) else { break }
            items.append(item)
            index += 1
        }

        if !items.isEmpty {
            blocks.append(.taskList(items: items))
        }

        return index
    }
}

// MARK: - Private: Lists

private extension MarkdownParser {
    static func parseUnorderedListItem(_ line: String) -> (depth: Int, content: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let leadingSpaces = line.prefix(while: { $0 == " " }).count

        guard trimmed.count >= 2 else { return nil }
        let secondChar = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)]

        let validMarkers: [Character] = ["-", "*", "+"]
        guard validMarkers.contains(trimmed.first ?? " ") && (secondChar == " " || secondChar == "\t") else {
            return nil
        }

        let content = String(trimmed.dropFirst(2)).trimmingPrefix(" ")
        return (leadingSpaces / 2, content)
    }

    static func parseUnorderedList(
        lines: [String],
        startIndex: Int,
        into blocks: inout [MessageBlock]
    ) -> Int {
        var index = startIndex
        var items: [MarkdownListItem] = []

        while index < lines.count {
            guard let (depth, content) = parseUnorderedListItem(lines[index]) else { break }
            items.append(MarkdownListItem(content: content, depth: depth))
            index += 1
        }

        if !items.isEmpty {
            blocks.append(.unorderedList(items: items))
        }

        return index
    }

    static func parseOrderedListItem(_ line: String) -> OrderedListItemMatch? {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        let digits = trimmed.prefix(while: { $0.isNumber })
        guard let number = Int(digits), !digits.isEmpty else { return nil }

        let afterDigits = trimmed.dropFirst(digits.count)
        guard afterDigits.hasPrefix(".") else { return nil }

        let afterDot = afterDigits.dropFirst()
        guard afterDot.isEmpty || afterDot.hasPrefix(" ") || afterDot.hasPrefix("\t") else { return nil }

        let content = String(afterDot).trimmingPrefix(" ")
        return OrderedListItemMatch(number: number, depth: leadingSpaces / 2, content: content)
    }

    static func parseOrderedList(lines: [String], startIndex: Int, into blocks: inout [MessageBlock]) -> Int {
        var index = startIndex
        var items: [MarkdownOrderedListItem] = []

        while index < lines.count {
            guard let match = parseOrderedListItem(lines[index]) else { break }
            items.append(MarkdownOrderedListItem(number: match.number, content: match.content, depth: match.depth))
            index += 1
        }

        if !items.isEmpty {
            blocks.append(.orderedList(items: items))
        }

        return index
    }
}

// MARK: - Private: Table

private extension MarkdownParser {
    static func tryParseTable(lines: [String], startIndex: Int) -> MessageBlock? {
        guard startIndex + 1 < lines.count else { return nil }

        let headerLine = lines[startIndex]
        let separatorLine = lines[startIndex + 1]

        let headers = parseTableRow(headerLine)
        guard !headers.isEmpty else { return nil }
        guard isTableSeparator(separatorLine, columnCount: headers.count) else { return nil }

        var rows: [[String]] = []
        var index = startIndex + 2

        while index < lines.count {
            let row = parseTableRow(lines[index])
            if row.isEmpty { break }
            rows.append(row)
            index += 1
        }

        return .table(headers: headers, rows: rows)
    }

    static func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") || trimmed.hasSuffix("|") else { return [] }

        let cells = trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let startIndex = trimmed.hasPrefix("|") ? 1 : 0
        let endIndex = cells.count - (trimmed.hasSuffix("|") ? 1 : 0)

        guard startIndex < min(cells.count, endIndex + 1) else { return [] }

        let filtered = Array(cells[startIndex..<endIndex])
        return filtered.isEmpty ? [] : filtered
    }

    static func isTableSeparator(_ line: String, columnCount: Int) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") && trimmed.contains("-") else { return false }

        let cells = parseTableRow(line)
        guard cells.count == columnCount else { return false }

        return cells.allSatisfy { cell in
            let cleaned = cell.trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty else { return false }
            let withoutColons = cleaned.replacingOccurrences(of: ":", with: "")
            return withoutColons.allSatisfy { $0 == "-" }
        }
    }

    static func advancePastTable(lines: [String], startIndex: Int) -> Int {
        var index = startIndex + 2
        while index < lines.count {
            let row = parseTableRow(lines[index])
            if row.isEmpty { break }
            index += 1
        }
        return index
    }
}

// MARK: - Private: Code & Headings

private extension MarkdownParser {
    static func extractLanguage(from fenceLine: String) -> String? {
        let trimmed = fenceLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 3 else { return nil }
        let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return lang.isEmpty ? nil : lang
    }

    static func extractHeading(from line: String) -> (Int, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for level in 1...6 {
            let prefix = String(repeating: "#", count: level) + " "
            if trimmed.hasPrefix(prefix) {
                let text = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                return (level, text)
            }
        }
        return nil
    }
}

// MARK: - String Helpers

private extension String {
    func trimmingPrefix(_ character: Character) -> String {
        String(self.drop(while: { $0 == character }))
    }

    func trimmingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
