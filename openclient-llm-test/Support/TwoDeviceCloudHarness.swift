//
//  TwoDeviceCloudHarness.swift
//  openclient-llm-test
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

@MainActor
final class TwoDeviceCloudHarness {
    // MARK: - Properties

    let rootURL: URL
    let cloudContainerURL: URL
    let cloudProvider: MutableTestCloudContainerProvider
    let deviceA: Device
    let deviceB: Device

    var cloudDocumentsURL: URL {
        cloudContainerURL.appendingPathComponent("Documents", isDirectory: true)
    }

    // MARK: - Init

    init() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwoDeviceCloudHarness-\(UUID().uuidString)", isDirectory: true)
        let cloudContainerURL = rootURL.appendingPathComponent("Cloud-AccountA", isDirectory: true)
        try FileManager.default.createDirectory(at: cloudContainerURL, withIntermediateDirectories: true)
        let cloudProvider = MutableTestCloudContainerProvider(
            containerURL: cloudContainerURL,
            identity: Data("account-a".utf8)
        )
        let deviceA = try Device(name: "DeviceA", rootURL: rootURL, cloudProvider: cloudProvider)
        let deviceB = try Device(name: "DeviceB", rootURL: rootURL, cloudProvider: cloudProvider)
        self.rootURL = rootURL
        self.cloudContainerURL = cloudContainerURL
        self.cloudProvider = cloudProvider
        self.deviceA = deviceA
        self.deviceB = deviceB
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    // MARK: - Helpers

    func synchronize(_ device: Device) async -> AppSynchronizationResult {
        await device.synchronizeAppData.execute()
    }

    func synchronizeBoth(startingWith first: Device? = nil) async -> (
        AppSynchronizationResult,
        AppSynchronizationResult
    ) {
        let first = first ?? deviceA
        let second = first === deviceA ? deviceB : deviceA
        return (await synchronize(first), await synchronize(second))
    }

    func cloudBytes() throws -> [String: Data] {
        try bytes(in: cloudDocumentsURL)
    }

    func cloudContainerURL(account: String) -> URL {
        rootURL.appendingPathComponent("Cloud-\(account)", isDirectory: true)
    }

    func switchCloudAccount(
        to account: String,
        identity: Data,
        metadataReady: Bool = false
    ) throws -> URL {
        let containerURL = cloudContainerURL(account: account)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        cloudProvider.switchAccount(
            containerURL: containerURL,
            identity: identity,
            metadataReady: metadataReady
        )
        return containerURL
    }

    func bytes(in root: URL) throws -> [String: Data] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [:] }
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var result: [String: Data] = [:]
        while let url = enumerator?.nextObject() as? URL {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let relativePath = String(url.path.dropFirst(root.path.count + 1))
            result[relativePath] = try Data(contentsOf: url)
        }
        return result
    }
}

// MARK: - Device

extension TwoDeviceCloudHarness {
    @MainActor
    final class Device {
        let documentsURL: URL
        let defaults: UserDefaults
        let defaultsSuiteName: String
        let settings: SettingsManager
        let cloud: CloudSyncManager
        let conversations: ConversationRepository
        let profile: UserProfileManager
        let memory: MemoryManager
        let templates: PromptTemplateRepository
        let runtimeStore: CloudSyncRuntimeStore
        let accountAssociation: CloudAccountAssociation
        let enableCloudSync: EnableCloudSyncUseCase
        let synchronizeAppData: SynchronizeAppDataUseCase
        let cloudDataManagement: CloudDataManagementUseCase

        init(name: String, rootURL: URL, cloudProvider: CloudContainerProviding) throws {
            let storage = try TwoDeviceCloudHarnessBuilder.makeStorage(name: name, rootURL: rootURL)
            let cloudStack = try TwoDeviceCloudHarnessBuilder.makeCloudStack(
                settings: storage.settings,
                cloudProvider: cloudProvider
            )
            let repositories = TwoDeviceCloudHarnessBuilder.makeRepositories(
                storage: storage,
                cloudStack: cloudStack
            )
            let operations = TwoDeviceCloudHarnessBuilder.makeOperations(
                storage: storage,
                cloudStack: cloudStack,
                repositories: repositories,
                cloudProvider: cloudProvider
            )
            documentsURL = storage.documentsURL
            defaults = storage.defaults
            defaultsSuiteName = storage.defaultsSuiteName
            settings = storage.settings
            cloud = cloudStack.cloud
            conversations = repositories.conversations
            profile = repositories.profile
            memory = repositories.memory
            templates = repositories.templates
            runtimeStore = operations.runtimeStore
            accountAssociation = cloudStack.accountAssociation
            enableCloudSync = operations.enableCloudSync
            synchronizeAppData = operations.synchronizeAppData
            cloudDataManagement = operations.cloudDataManagement
        }

        deinit {
            UserDefaults(suiteName: defaultsSuiteName)?.removePersistentDomain(forName: defaultsSuiteName)
        }

        func writeConversation(_ conversation: Conversation) throws {
            let directory = documentsURL.appendingPathComponent("Conversations", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try SyncJSONCoding.makeEncoder().encode(conversation).write(
                to: directory.appendingPathComponent("\(conversation.id.uuidString).json"),
                options: .atomic
            )
        }

        func writeAttachment(_ data: Data, for attachment: ChatMessage.Attachment) throws {
            let url = documentsURL.appendingPathComponent(attachment.fileRelativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        }

        func customTemplates() async throws -> [PromptTemplate] {
            try await templates.loadAll().filter { !$0.isBuiltIn }
        }

        func preflightAndApproveCurrentAccount() async throws -> CloudSyncEnablementPreflight {
            let fingerprint = accountAssociation.currentAccountFingerprint()
            let result = try await enableCloudSync.execute()
            guard let fingerprint else { throw CloudAccountAssociationError.unavailable }
            try accountAssociation.approveCurrentAccount(expectedFingerprint: fingerprint)
            let generation = runtimeStore.begin(.idle(lastSuccessfulSyncAt: nil))
            _ = runtimeStore.completePreflight(generation: generation)
            return result
        }
    }
}

// MARK: - Device Builders

@MainActor
private enum TwoDeviceCloudHarnessBuilder {
    struct Storage {
        let documentsURL: URL
        let defaults: UserDefaults
        let defaultsSuiteName: String
        let settings: SettingsManager
    }

    struct CloudStack {
        let accountAssociation: CloudAccountAssociation
        let mutationGate: CloudSynchronizationMutationGate
        let categoryGate: CloudCategoryOperationGate
        let cloud: CloudSyncManager
    }

    struct Repositories {
        let conversations: ConversationRepository
        let profile: UserProfileManager
        let memory: MemoryManager
        let templates: PromptTemplateRepository
    }

    struct Operations {
        let runtimeStore: CloudSyncRuntimeStore
        let enableCloudSync: EnableCloudSyncUseCase
        let synchronizeAppData: SynchronizeAppDataUseCase
        let cloudDataManagement: CloudDataManagementUseCase
    }

    static func makeStorage(name: String, rootURL: URL) throws -> Storage {
        let documentsURL = rootURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let defaultsSuiteName = "TwoDeviceCloudHarness.\(name).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsSuiteName) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let settings = SettingsManager(defaults: defaults, keychainManager: MockKeychainManager())
        settings.setIsCloudSyncEnabled(true)
        return Storage(
            documentsURL: documentsURL,
            defaults: defaults,
            defaultsSuiteName: defaultsSuiteName,
            settings: settings
        )
    }

    static func makeCloudStack(
        settings: SettingsManager,
        cloudProvider: CloudContainerProviding
    ) throws -> CloudStack {
        let accountAssociation = CloudAccountAssociation(
            settingsManager: settings,
            containerProvider: cloudProvider
        )
        guard let initialFingerprint = accountAssociation.currentAccountFingerprint() else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        try accountAssociation.approveCurrentAccount(expectedFingerprint: initialFingerprint)
        let mutationGate = CloudSynchronizationMutationGate()
        let categoryGate = CloudCategoryOperationGate()
        let cloud = CloudSyncManager(
            containerProvider: cloudProvider,
            categoryOperationGate: categoryGate,
            mutationGate: mutationGate
        )
        return CloudStack(
            accountAssociation: accountAssociation,
            mutationGate: mutationGate,
            categoryGate: categoryGate,
            cloud: cloud
        )
    }

    static func makeRepositories(storage: Storage, cloudStack: CloudStack) -> Repositories {
        let conversations = ConversationRepository(
            settingsManager: storage.settings,
            cloudSyncManager: cloudStack.cloud,
            attachmentRepository: AttachmentRepository(baseURL: storage.documentsURL),
            baseDirectory: storage.documentsURL,
            mutationGate: cloudStack.mutationGate
        )
        let profile = UserProfileManager(
            settingsManager: storage.settings,
            cloudSyncManager: cloudStack.cloud,
            defaults: storage.defaults,
            legacyCloudStore: EmptyLegacyProfileStore(),
            documentsURL: storage.documentsURL,
            mutationGate: cloudStack.mutationGate
        )
        let memory = MemoryManager(
            settingsManager: storage.settings,
            cloudSyncManager: cloudStack.cloud,
            documentsURL: storage.documentsURL,
            userDefaults: storage.defaults,
            mutationGate: cloudStack.mutationGate,
            categoryOperationGate: cloudStack.categoryGate
        )
        let templates = PromptTemplateRepository(
            settingsManager: storage.settings,
            cloudSyncManager: cloudStack.cloud,
            directoryURL: storage.documentsURL.appendingPathComponent("PromptTemplates", isDirectory: true),
            mutationGate: cloudStack.mutationGate,
            operationGate: PromptTemplateOperationGate()
        )
        return Repositories(
            conversations: conversations,
            profile: profile,
            memory: memory,
            templates: templates
        )
    }

    static func makeOperations(
        storage: Storage,
        cloudStack: CloudStack,
        repositories: Repositories,
        cloudProvider: CloudContainerProviding
    ) -> Operations {
        let runtimeStore = CloudSyncRuntimeStore(status: .idle(lastSuccessfulSyncAt: nil))
        let generation = runtimeStore.begin(.idle(lastSuccessfulSyncAt: nil))
        _ = runtimeStore.completePreflight(generation: generation)
        let synchronizeAppData = SynchronizeAppDataUseCase(
            syncConversationsUseCase: SyncConversationsUseCase(repository: repositories.conversations),
            userProfileManager: repositories.profile,
            memoryManager: repositories.memory,
            promptTemplateRepository: repositories.templates,
            settingsManager: storage.settings,
            synchronizationGate: FullAppSynchronizationGate(),
            mutationGate: cloudStack.mutationGate,
            runtimeStore: runtimeStore,
            accountAssociation: cloudStack.accountAssociation,
            now: { Date(timeIntervalSince1970: 4_000_000_000) }
        )
        let enableCloudSync = EnableCloudSyncUseCase(
            cloudSyncManager: cloudStack.cloud,
            userProfileManager: repositories.profile,
            hasUbiquityIdentity: { cloudProvider.identityData() != nil }
        )
        let cloudDataManagement = CloudDataManagementUseCase(
            cloudSyncManager: cloudStack.cloud,
            conversationRepository: repositories.conversations,
            userProfileManager: repositories.profile,
            memoryManager: repositories.memory,
            promptTemplateRepository: repositories.templates,
            settingsManager: storage.settings,
            mutationGate: cloudStack.mutationGate
        )
        return Operations(
            runtimeStore: runtimeStore,
            enableCloudSync: enableCloudSync,
            synchronizeAppData: synchronizeAppData,
            cloudDataManagement: cloudDataManagement
        )
    }
}

// Safety: This immutable test double has no mutable state.
private struct EmptyLegacyProfileStore: LegacyUserProfileCloudStore, Sendable {
    func string(forKey key: String) -> String? { nil }
    func removeObject(forKey key: String) {}
    func synchronize() {}
}

// Safety: All mutable provider state is protected by `lock`.
nonisolated final class MutableTestCloudContainerProvider: CloudContainerProviding, @unchecked Sendable {
    // MARK: - Properties

    private let lock = NSLock()
    private var available: Bool
    private var metadataReady: Bool
    private var rootURL: URL
    private var identity: Data

    // MARK: - Init

    init(
        containerURL: URL,
        available: Bool = true,
        metadataReady: Bool = true,
        identity: Data
    ) {
        self.available = available
        self.metadataReady = metadataReady
        self.rootURL = containerURL.standardizedFileURL
        self.identity = identity
    }

    // MARK: - CloudContainerProviding

    func isAvailable() -> Bool {
        lock.withLock { available }
    }

    func isMetadataReady(for session: CloudSyncSession) -> Bool {
        lock.withLock {
            available
                && metadataReady
                && session.containerURL == rootURL
                && session.identity == identity
        }
    }

    func containerURL() -> URL? {
        lock.withLock { rootURL }
    }

    func identityData() -> Data? {
        lock.withLock { available ? identity : nil }
    }

    func currentSession() -> CloudSyncSession? {
        lock.withLock {
            guard available else { return nil }
            return CloudSyncSession(containerURL: rootURL, identity: identity)
        }
    }

    // MARK: - Test Controls

    func setAvailable(_ available: Bool) {
        lock.withLock { self.available = available }
    }

    func setMetadataReady(_ metadataReady: Bool) {
        lock.withLock { self.metadataReady = metadataReady }
    }

    func switchAccount(containerURL: URL, identity: Data, metadataReady: Bool = false) {
        lock.withLock {
            rootURL = containerURL.standardizedFileURL
            self.identity = identity
            self.metadataReady = metadataReady
            available = true
        }
    }
}
