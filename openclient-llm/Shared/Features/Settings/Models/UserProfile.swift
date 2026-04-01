//
//  UserProfile.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct UserProfile: Equatable, Sendable, Codable {
    // MARK: - Properties

    var name: String
    var profileDescription: String
    var extraInfo: String

    // MARK: - Init

    init(name: String = "", profileDescription: String = "", extraInfo: String = "") {
        self.name = name
        self.profileDescription = profileDescription
        self.extraInfo = extraInfo
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
}
