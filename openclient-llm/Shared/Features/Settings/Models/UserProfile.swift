//
//  UserProfile.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct UserProfile: Equatable, Sendable, Codable {
    // MARK: - Properties

    private enum CodingKeys: String, CodingKey {
        case name
        case profileDescription
        case extraInfo
        case modifiedAt
    }

    var name: String
    var profileDescription: String
    var extraInfo: String
    var modifiedAt: Date

    // MARK: - Init

    init(
        name: String = "",
        profileDescription: String = "",
        extraInfo: String = "",
        modifiedAt: Date = Date()
    ) {
        self.name = name
        self.profileDescription = profileDescription
        self.extraInfo = extraInfo
        self.modifiedAt = Self.canonicalRevision(modifiedAt)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        profileDescription = try container.decode(String.self, forKey: .profileDescription)
        extraInfo = try container.decode(String.self, forKey: .extraInfo)
        modifiedAt = Self.canonicalRevision(try Self.decodeRevision(from: container))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(profileDescription, forKey: .profileDescription)
        try container.encode(extraInfo, forKey: .extraInfo)
        try container.encode(Self.formatRevision(modifiedAt), forKey: .modifiedAt)
    }

    // MARK: - Computed

    var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
            && profileDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && extraInfo.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Builds the personal context block to be prepended to any system prompt.
    var systemPromptContext: String {
        guard !isEmpty else { return "" }

        var parts: [String] = []
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("The user's name is \(name.trimmingCharacters(in: .whitespaces)).")
        }
        if !profileDescription.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("About the user: \(profileDescription.trimmingCharacters(in: .whitespaces))")
        }
        if !extraInfo.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("Additional context: \(extraInfo.trimmingCharacters(in: .whitespaces))")
        }
        return parts.joined(separator: " ")
    }

    static func canonicalRevision(_ date: Date) -> Date {
        let milliseconds = (date.timeIntervalSinceReferenceDate * 1_000).rounded()
        return Date(timeIntervalSinceReferenceDate: milliseconds / 1_000)
    }
}

// MARK: - Private

private extension UserProfile {
    private nonisolated static func decodeRevision(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Date {
        guard container.contains(.modifiedAt) else { return .distantPast }
        if let interval = try? container.decode(Double.self, forKey: .modifiedAt) {
            return Date(timeIntervalSinceReferenceDate: interval)
        }
        let value = try container.decode(String.self, forKey: .modifiedAt)
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else {
            throw DecodingError.dataCorruptedError(
                forKey: .modifiedAt,
                in: container,
                debugDescription: "Invalid profile modification date."
            )
        }
        return date
    }

    private nonisolated static func formatRevision(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        return formatter.string(from: date)
    }
}
