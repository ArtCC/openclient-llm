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
                await MainActor.run { self.reloadConversations() }
            }
        }
    }

    func observeCloudConversationChanges() {
        Task { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .conversationCloudDidChange)
            for await _ in notifications {
                guard let self else { return }
                self.cloudChangeTask?.cancel()
                self.cloudChangeTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    self?.synchronizeAndReloadConversations()
                }
            }
        }
    }
}
