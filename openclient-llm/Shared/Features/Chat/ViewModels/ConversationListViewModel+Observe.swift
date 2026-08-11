//
//  ConversationListViewModel+Observe.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 17/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension ConversationListViewModel {
    func observeAppDataReset() {
        Task { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .appDataDidReset)
            for await _ in notifications {
                guard let self else { return }
                await MainActor.run {
                    self.hasStartedInitialLoad = false
                    self.loadData()
                }
            }
        }
    }

    func observeConversationUpdated() {
        Task { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .conversationDidUpdate)
            for await _ in notifications {
                guard let self else { return }
                await self.reloadConversations()
            }
        }
    }

}
