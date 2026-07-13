//
//  ConversationCloudObserver.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol ConversationCloudObserving: AnyObject, Sendable {
    func start()
}

// Safety: NSMetadataQuery callbacks are delivered to .main and its mutable state is
// accessed only there. Dependencies are Sendable file-based managers.
final class ConversationCloudObserver: ConversationCloudObserving, @unchecked Sendable {
    // MARK: - Properties

    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private nonisolated(unsafe) var metadataQuery: NSMetadataQuery?
    private nonisolated(unsafe) var queryObserver: NSObjectProtocol?

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager()
    ) {
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
    }

    // MARK: - Public

    func start() {
        guard metadataQuery == nil, cloudSyncManager.isCloudAvailable() else { return }
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(
            format: "%K CONTAINS %@ OR %K CONTAINS %@ OR %K CONTAINS %@",
            NSMetadataItemPathKey,
            "/Conversations/",
            NSMetadataItemPathKey,
            "/ConversationTombstones/",
            NSMetadataItemPathKey,
            "/Attachments/"
        )
        queryObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.settingsManager.getIsCloudSyncEnabled() else { return }
                NotificationCenter.default.post(name: .conversationCloudDidChange, object: nil)
            }
        }
        metadataQuery = query
        query.start()
    }

    deinit {
        metadataQuery?.stop()
        if let queryObserver {
            NotificationCenter.default.removeObserver(queryObserver)
        }
    }
}
