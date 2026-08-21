//
//  ChatConversationInput.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 21/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

final class ChatConversationInput {
    struct Revision: Equatable {
        let id: UUID
        let updatedAt: Date
    }

    let conversation: Conversation

    init(_ conversation: Conversation) {
        self.conversation = conversation
    }

    var revision: Revision {
        Revision(id: conversation.id, updatedAt: conversation.updatedAt)
    }
}
