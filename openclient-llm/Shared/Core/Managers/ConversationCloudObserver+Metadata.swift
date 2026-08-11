//
//  ConversationCloudObserver+Metadata.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

extension ConversationCloudObserver {
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

    func completeStart(session: CloudSyncSession?, generation: Int, runtimeGeneration: Int) {
        guard generation == startGeneration else { return }
        startTask = nil
        guard let session else {
            let reason: CloudSyncStatus.UnavailableReason = fileManager.ubiquityIdentityToken == nil
                ? .accountUnavailable
                : .containerUnavailable
            runtimeStore.publish(.unavailable(reason), generation: runtimeGeneration)
            return
        }
        guard startContext?.approvingCurrentAccount == true || accountAssociation.state() == .matched else {
            runtimeStore.publish(.failed(.init(
                reason: .accountChanged,
                affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
            )), generation: runtimeGeneration)
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
            resetObservation()
            runtimeStore.publish(.failed(.init(
                reason: .fileAccess,
                affectedCategories: Set(CloudSyncStatus.DataCategory.allCases)
            )), generation: runtimeGeneration)
        }
    }

    func resetObservation() {
        metadataReadiness.reset()
        metadataQuery?.stop()
        metadataQuery = nil
        metadataSession = nil
        startContext = nil
        hasEstablishedBaseline = false
        contentFingerprints = [:]
        for observer in queryObservers { notificationCenter.removeObserver(observer) }
        queryObservers = []
        synchronizationGeneration += 1
        synchronizationTask?.cancel()
        synchronizationTask = nil
        metadataDebounceTask?.cancel()
        metadataDebounceTask = nil
        needsSynchronization = false
        let syncUseCase = synchronizeAppDataUseCase
        cancellationTask = Task { await syncUseCase.cancel() }
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

    func metadataState(in query: NSMetadataQuery) -> MetadataState {
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
        return MetadataState(hasContentChanges: hasContentChanges, hasPendingDownloads: hasPendingDownloads)
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
                self.publishMetadataPending()
                return
            }
            self.hasEstablishedBaseline = true
            self.metadataReadiness.setReady(for: session)
            self.startPreflightAfterMetadataBaseline(for: session)
        }
    }

    func startPreflightAfterMetadataBaseline(for session: CloudSyncSession) {
        guard let context = startContext,
              context.generation == startGeneration,
              metadataSession == session,
              hasEstablishedBaseline,
              metadataReadiness.isReady(for: session),
              settingsManager.getIsCloudSyncEnabled() else { return }
        let enableCloudSyncUseCase = enableCloudSyncUseCase
        startTask?.cancel()
        startTask = Task { [weak self] in
            do {
                let preflight = try await enableCloudSyncUseCase.execute()
                guard !Task.isCancelled, let self else { return }
                completePreflight(preflight, context: context, session: session)
            } catch {
                guard let self else { return }
                completePreflightFailure(
                    error,
                    generation: context.generation,
                    runtimeGeneration: context.runtimeGeneration
                )
            }
        }
    }

    func completePreflight(
        _ preflight: CloudSyncEnablementPreflight,
        context: StartContext,
        session: CloudSyncSession
    ) {
        guard context.generation == startGeneration,
              metadataSession == session,
              settingsManager.getIsCloudSyncEnabled() else { return }
        guard !context.approvingCurrentAccount || approveAccount(
            fingerprint: context.approvalFingerprint,
            generation: context.generation,
            runtimeGeneration: context.runtimeGeneration
        ) else { return }
        guard preflight == .ready else {
            completeProfileConflict(
                generation: context.generation,
                runtimeGeneration: context.runtimeGeneration
            )
            return
        }
        guard runtimeStore.completePreflight(generation: context.runtimeGeneration) else { return }
        startTask = nil
        startContext = nil
        guard runtimeStore.publish(.idle(
            lastSuccessfulSyncAt: settingsManager.getLastSuccessfulCloudSyncDate()
        ), generation: context.runtimeGeneration) else { return }
        startSynchronization()
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
                    self.publishMetadataPending()
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
                    self.publishMetadataPending()
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
}
