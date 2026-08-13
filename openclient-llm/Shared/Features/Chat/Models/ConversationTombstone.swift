//
//  ConversationTombstone.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct ConversationTombstone: Codable, Equatable, Sendable {
    let conversationId: UUID
    let deletedAt: Date
}
