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
    private var contentChangeDates: [String: Date] = [:]
    private var hasEstablishedBaseline = false

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
                guard let self,
                      let query = self.metadataQuery,
                      self.settingsManager.getIsCloudSyncEnabled() else { return }
                guard self.hasContentChanges(in: query) else { return }
                guard self.hasEstablishedBaseline else {
                    self.hasEstablishedBaseline = true
                    return
                }
                NotificationCenter.default.post(name: .conversationCloudDidChange, object: nil)
            }
        }
        metadataQuery = query
        query.start()
    }

    private func hasContentChanges(in query: NSMetadataQuery) -> Bool {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var latestContentChangeDates: [String: Date] = [:]
        for case let item as NSMetadataItem in query.results {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let changeDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date ?? .distantPast
            latestContentChangeDates[path] = changeDate
        }

        guard latestContentChangeDates != contentChangeDates else { return false }
        contentChangeDates = latestContentChangeDates
        return true
    }

    deinit {
        metadataQuery?.stop()
        if let queryObserver {
            NotificationCenter.default.removeObserver(queryObserver)
        }
    }
}
