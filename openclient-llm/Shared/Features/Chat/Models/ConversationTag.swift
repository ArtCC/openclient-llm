//
//  ConversationTag.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 14/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct ConversationTag: Equatable, Hashable, Sendable, Codable {
    let name: String
    let color: TagColor
}
