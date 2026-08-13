//
//  ConversationCloudObserver+Lifecycle.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ConversationCloudObserver {
    func observeLifecycleChanges() {
        let intentObserver = notificationCenter.addObserver(
            forName: .cloudSyncIntentDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.settingsManager.getIsCloudSyncEnabled() {
                    self.start()
                } else {
                    self.stop()
                }
            }
        }
        let identityObserver = notificationCenter.addObserver(
            forName: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.metadataReadiness.reset()
                self.stop()
                self.start()
            }
        }
        lifecycleObservers = [intentObserver, identityObserver]
    }
}
