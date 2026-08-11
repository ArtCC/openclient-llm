//
//  ConversationCloudObserver.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/07/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@MainActor
final class ConversationCloudObserver {
    // MARK: - Properties

    static let synchronizedPathComponents = [
        "SyncManifest.json",
        "UserProfile.json",
        "UserProfileDeletion.json",
        "Memory.json",
        "MemoryTombstones.json",
        "/PromptTemplates",
        "/PromptTemplateTombstones",
        "/Conversations",
        "/ConversationTombstones",
        "ConversationTombstones.json",
        "ConversationDeleteAll.json",
        "/Attachments"
    ]

    private let settingsManager: SettingsManagerProtocol
    private let cloudSyncManager: CloudSyncManagerProtocol
    private let syncConversationsUseCase: SyncConversationsUseCaseProtocol
    private let notificationCenter: NotificationCenter
    private let metadataReadiness: CloudMetadataReadiness
    private let containerProvider: CloudContainerProviding
    private let fileManager: FileManager
    private let metadataDebounceDuration: Duration
    private var metadataQuery: NSMetadataQuery?
    private var metadataSession: CloudSyncSession?
    private var queryObservers: [NSObjectProtocol] = []
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var contentFingerprints: [String: ContentFingerprint] = [:]
    private var hasEstablishedBaseline = false
    private var synchronizationTask: Task<Void, Never>?
    private var cancellationTask: Task<Void, Never>?
    private var metadataDebounceTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var needsSynchronization = false
    private var synchronizationGeneration = 0
    private var startGeneration = 0

    // MARK: - Init

    init(
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        cloudSyncManager: CloudSyncManagerProtocol = CloudSyncManager(),
        syncConversationsUseCase: SyncConversationsUseCaseProtocol = SyncConversationsUseCase(),
        notificationCenter: NotificationCenter = .default,
        metadataReadiness: CloudMetadataReadiness = .shared,
        containerProvider: CloudContainerProviding? = nil,
        fileManager: FileManager = .default,
        metadataDebounceDuration: Duration = .milliseconds(500)
    ) {
        self.settingsManager = settingsManager
        self.cloudSyncManager = cloudSyncManager
        self.syncConversationsUseCase = syncConversationsUseCase
        self.notificationCenter = notificationCenter
        self.metadataReadiness = metadataReadiness
        self.containerProvider = containerProvider ?? UbiquityCloudContainerProvider(
            fileManager: fileManager,
            metadataReadiness: metadataReadiness
        )
        self.fileManager = fileManager
        self.metadataDebounceDuration = metadataDebounceDuration
        observeLifecycleChanges()
    }

    // MARK: - Public

    func start() {
        guard settingsManager.getIsCloudSyncEnabled() else {
            stop()
            return
        }
        startGeneration += 1
        let generation = startGeneration
        startTask?.cancel()
        let resolution = resolveCurrentSession()
        startTask = Task { [weak self] in
            let session = await resolution.value
            guard !Task.isCancelled, let self else { return }
            completeStart(session: session, generation: generation)
        }
    }

    func stop() {
        startGeneration += 1
        startTask?.cancel()
        startTask = nil
        metadataReadiness.reset()
        metadataQuery?.stop()
        metadataQuery = nil
        metadataSession = nil
        hasEstablishedBaseline = false
        contentFingerprints = [:]
        for observer in queryObservers {
            notificationCenter.removeObserver(observer)
        }
        queryObservers = []
        synchronizationGeneration += 1
        synchronizationTask?.cancel()
        synchronizationTask = nil
        metadataDebounceTask?.cancel()
        metadataDebounceTask = nil
        needsSynchronization = false
        let syncUseCase = syncConversationsUseCase
        cancellationTask = Task { await syncUseCase.cancel() }
    }

    func handleMetadataChange() {
        guard hasEstablishedBaseline,
              let metadataSession,
              metadataReadiness.isReady(for: metadataSession) else { return }
        metadataDebounceTask?.cancel()
        metadataDebounceTask = Task { [weak self, metadataDebounceDuration] in
            try? await Task.sleep(for: metadataDebounceDuration)
            guard !Task.isCancelled, let self else { return }
            startSynchronization()
        }
    }

    private func completeStart(session: CloudSyncSession?, generation: Int) {
        guard generation == startGeneration else { return }
        startTask = nil
        guard let session else {
            stop()
            return
        }
        if metadataQuery != nil {
            guard metadataSession != session else { return }
            stop()
            start()
            return
        }
        metadataReadiness.reset()
        metadataSession = session
        let query = makeMetadataQuery()
        let queryReference = MetadataQueryReference(query)
        queryObservers = [
            makeGatheringObserver(for: query, reference: queryReference),
            makeUpdateObserver(for: query, reference: queryReference)
        ]
        metadataQuery = query
        if !query.start() {
            stop()
        }
    }

    private func startSynchronization() {
        guard settingsManager.getIsCloudSyncEnabled(),
              hasEstablishedBaseline,
              let metadataSession,
              metadataReadiness.isReady(for: metadataSession) else { return }
        guard synchronizationTask == nil else {
            needsSynchronization = true
            return
        }

        let generation = synchronizationGeneration
        let pendingCancellation = cancellationTask
        synchronizationTask = Task { [weak self] in
            guard let self else { return }
            await pendingCancellation?.value
            guard synchronizationGeneration == generation else { return }
            repeat {
                needsSynchronization = false
                _ = await syncConversationsUseCase.execute()
                guard synchronizationGeneration == generation else { return }
                guard !Task.isCancelled,
                      settingsManager.getIsCloudSyncEnabled() else { break }
                notificationCenter.post(name: .conversationDidUpdate, object: nil)
            } while needsSynchronization
            if synchronizationGeneration == generation {
                synchronizationTask = nil
            }
        }
    }

    static func requiresDownload(forDownloadingStatus status: String?) -> Bool {
        guard let status else { return false }
        return status != NSMetadataUbiquitousItemDownloadingStatusCurrent
    }

    private func metadataState(in query: NSMetadataQuery) -> MetadataState {
        query.disableUpdates()
        defer { query.enableUpdates() }

        var latestFingerprints: [String: ContentFingerprint] = [:]
        var hasPendingDownloads = false
        for case let item as NSMetadataItem in query.results {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let changeDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date ?? .distantPast
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            latestFingerprints[path] = ContentFingerprint(changeDate: changeDate, downloadingStatus: status)
            guard Self.requiresDownload(forDownloadingStatus: status) else { continue }
            hasPendingDownloads = true
            if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                try? fileManager.startDownloadingUbiquitousItem(at: url)
            }
        }

        let hasContentChanges = latestFingerprints != contentFingerprints
        contentFingerprints = latestFingerprints
        return MetadataState(
            hasContentChanges: hasContentChanges,
            hasPendingDownloads: hasPendingDownloads
        )
    }

    isolated deinit {
        metadataReadiness.reset()
        metadataQuery?.stop()
        synchronizationTask?.cancel()
        cancellationTask?.cancel()
        metadataDebounceTask?.cancel()
        startTask?.cancel()
        for observer in queryObservers {
            notificationCenter.removeObserver(observer)
        }
        for observer in lifecycleObservers {
            notificationCenter.removeObserver(observer)
        }
    }
}

private extension ConversationCloudObserver {
    // Safety: The query is created on MainActor and accessed only by callbacks delivered on the main queue.
    final class MetadataQueryReference: @unchecked Sendable {
        let query: NSMetadataQuery

        init(_ query: NSMetadataQuery) {
            self.query = query
        }
    }

    struct ContentFingerprint: Equatable {
        let changeDate: Date
        let downloadingStatus: String?
    }

    struct MetadataState {
        let hasContentChanges: Bool
        let hasPendingDownloads: Bool
    }

    func resolveCurrentSession() -> Task<CloudSyncSession?, Never> {
        let cloudSyncManager = cloudSyncManager
        let containerProvider = containerProvider
        return Task.detached(priority: .utility) {
            guard cloudSyncManager.isCloudAvailable() else { return nil }
            return containerProvider.currentSession()
        }
    }

    func makeMetadataQuery() -> NSMetadataQuery {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: Self.synchronizedPathComponents.map {
                NSPredicate(format: "%K CONTAINS %@", NSMetadataItemPathKey, $0)
            }
        )
        return query
    }

    func establishBaseline(for query: NSMetadataQuery, session: CloudSyncSession) {
        let resolution = resolveCurrentSession()
        Task { [weak self] in
            let currentSession = await resolution.value
            guard let self,
                  self.metadataQuery === query,
                  self.settingsManager.getIsCloudSyncEnabled() else { return }
            guard currentSession == session else {
                self.stop()
                self.start()
                return
            }
            let state = self.metadataState(in: query)
            guard !state.hasPendingDownloads else {
                self.metadataReadiness.reset(for: session)
                return
            }
            self.hasEstablishedBaseline = true
            self.metadataReadiness.setReady(for: session)
            self.handleMetadataChange()
        }
    }

    func makeGatheringObserver(
        for query: NSMetadataQuery,
        reference: MetadataQueryReference
    ) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self, reference] _ in
            MainActor.assumeIsolated {
                let query = reference.query
                guard let self,
                      self.metadataQuery === query,
                      let session = self.metadataSession else { return }
                let state = self.metadataState(in: query)
                guard !state.hasPendingDownloads else {
                    self.metadataReadiness.reset(for: session)
                    return
                }
                self.establishBaseline(for: query, session: session)
            }
        }
    }

    func makeUpdateObserver(
        for query: NSMetadataQuery,
        reference: MetadataQueryReference
    ) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self, reference] _ in
            MainActor.assumeIsolated {
                let query = reference.query
                guard let self,
                      self.metadataQuery === query,
                      self.settingsManager.getIsCloudSyncEnabled(),
                      let session = self.metadataSession else { return }
                let state = self.metadataState(in: query)
                guard !state.hasPendingDownloads else {
                    self.hasEstablishedBaseline = false
                    self.metadataReadiness.reset(for: session)
                    return
                }
                guard self.hasEstablishedBaseline else {
                    self.establishBaseline(for: query, session: session)
                    return
                }
                guard state.hasContentChanges else { return }
                self.handleMetadataChange()
            }
        }
    }

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
