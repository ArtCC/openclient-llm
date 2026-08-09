//
//  ConversationListViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class ConversationListViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case newConversationTapped
        case newPrivateConversationTapped
        case refreshTapped
        case conversation(ConversationEvent)
        case filter(FilterEvent)
        case backup(BackupEvent)

        static func conversationTapped(_ conversation: Conversation) -> Self { .conversation(.tapped(conversation)) }
        static func deleteConversation(_ id: UUID) -> Self { .conversation(.deleted(id)) }
        static func pinToggled(_ id: UUID) -> Self { .conversation(.pinToggled(id)) }
        static func tagsUpdated(_ id: UUID, _ tags: [ConversationTag]) -> Self { .conversation(.tagsUpdated(id, tags)) }
        static func titleEdited(_ id: UUID, _ title: String) -> Self { .conversation(.titleEdited(id, title)) }
        static func searchChanged(_ query: String) -> Self { .filter(.searchChanged(query)) }
        static func tagFilterChanged(_ tag: String?) -> Self { .filter(.tagChanged(tag)) }
        static var exportBackupTapped: Self { .backup(.exportTapped) }
        static var backupDataConsumed: Self { .backup(.dataConsumed) }
        static func importBackupData(_ data: Data) -> Self { .backup(.imported(data)) }
        static var importResultConsumed: Self { .backup(.resultConsumed) }
        static var errorMessageConsumed: Self { .backup(.errorConsumed) }
        static var backupImportReadFailed: Self { .backup(.readFailed) }
        static var backupExportWriteFailed: Self { .backup(.exportWriteFailed) }
    }

    enum ConversationEvent {
        case tapped(Conversation)
        case deleted(UUID)
        case pinToggled(UUID)
        case tagsUpdated(UUID, [ConversationTag])
        case titleEdited(UUID, String)
    }

    enum FilterEvent {
        case searchChanged(String)
        case tagChanged(String?)
    }

    enum BackupEvent {
        case exportTapped
        case dataConsumed
        case imported(Data)
        case resultConsumed
        case errorConsumed
        case readFailed
        case exportWriteFailed
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var conversations: [Conversation] = []
        var selectedConversation: Conversation?
        var availableModels: [LLMModel] = []
        var errorMessage: String?
        var searchQuery: String = ""
        var filteredConversations: [Conversation] = []
        var activeTagFilter: String?
        var backupData: Data?
        var importResult: ImportConversationsResult?

        var allTags: [ConversationTag] {
            let tags = Dictionary(conversations.flatMap(\.tags).map { ($0.name, $0) },
                                  uniquingKeysWith: { first, _ in first }).values
            return tags.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        var groupedConversations: [ConversationSection] {
            ConversationSection.group(filteredConversations)
        }
    }

    private(set) var state: State

    private let loadConversationsUseCase: LoadConversationsUseCaseProtocol
    private let deleteConversationUseCase: DeleteConversationUseCaseProtocol
    private let pinConversationUseCase: PinConversationUseCaseProtocol
    private let updateConversationTagsUseCase: UpdateConversationTagsUseCaseProtocol
    private let renameConversationUseCase: RenameConversationUseCaseProtocol
    private let fetchModelsUseCase: FetchModelsUseCaseProtocol
    private let syncConversationsUseCase: SyncConversationsUseCaseProtocol
    private let exportBackupUseCase: ExportBackupUseCaseProtocol
    private let importConversationsUseCase: ImportConversationsUseCaseProtocol
    private let settingsManager: SettingsManagerProtocol
    private let conversationCloudObserver: ConversationCloudObserving
    private var errorDismissTask: Task<Void, Never>?
    var hasStartedInitialLoad = false

    var cloudChangeTask: Task<Void, Never>?
    var cloudRetryTask: Task<Void, Never>?
    var onConversationSelected: ((Conversation?) -> Void)?
    var onPrivateChatSelected: (() -> Void)?

    // MARK: - Init

    init(
        state: State = .loading,
        loadConversationsUseCase: LoadConversationsUseCaseProtocol = LoadConversationsUseCase(),
        deleteConversationUseCase: DeleteConversationUseCaseProtocol = DeleteConversationUseCase(),
        pinConversationUseCase: PinConversationUseCaseProtocol = PinConversationUseCase(),
        updateConversationTagsUseCase: UpdateConversationTagsUseCaseProtocol = UpdateConversationTagsUseCase(),
        renameConversationUseCase: RenameConversationUseCaseProtocol = RenameConversationUseCase(),
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        syncConversationsUseCase: SyncConversationsUseCaseProtocol = SyncConversationsUseCase(),
        exportBackupUseCase: ExportBackupUseCaseProtocol = ExportBackupUseCase(),
        importConversationsUseCase: ImportConversationsUseCaseProtocol = ImportConversationsUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager(),
        conversationCloudObserver: ConversationCloudObserving? = nil
    ) {
        self.state = state
        self.loadConversationsUseCase = loadConversationsUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
        self.pinConversationUseCase = pinConversationUseCase
        self.updateConversationTagsUseCase = updateConversationTagsUseCase
        self.renameConversationUseCase = renameConversationUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
        self.syncConversationsUseCase = syncConversationsUseCase
        self.exportBackupUseCase = exportBackupUseCase
        self.importConversationsUseCase = importConversationsUseCase
        self.settingsManager = settingsManager
        self.conversationCloudObserver = conversationCloudObserver
            ?? ConversationCloudObserver(settingsManager: settingsManager)
        observeAppDataReset()
        observeConversationUpdated()
        observeCloudConversationChanges()
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadData()
        case .newConversationTapped:
            createNewConversation()
        case .newPrivateConversationTapped:
            onPrivateChatSelected?()
        case .refreshTapped:
            refresh()
        case .conversation(let event):
            handleConversationEvent(event)
        case .filter(let event):
            handleFilterEvent(event)
        case .backup(let event):
            handleBackupEvent(event)
        }
    }

    func refresh() {
        synchronizeAndReloadConversations()
    }

    func refreshAsync() async {
        synchronizeAndReloadConversations()
        await Task.yield()
    }

    func loadData() {
        guard !hasStartedInitialLoad else { return }
        hasStartedInitialLoad = true
        state = .loading
        conversationCloudObserver.start()

        Task {
            do {
                let conversations = try loadConversationsUseCase.executeLocally()
                state = .loaded(LoadedState(
                    conversations: conversations,
                    filteredConversations: conversations
                ))

                // Let SwiftUI render local data before doing synchronous iCloud work.
                await Task.yield()
                synchronizeAndReloadConversations()
            } catch {
                state = .loaded(LoadedState(errorMessage: error.localizedDescription))
                scheduleErrorDismiss()
                return
            }

            var models: [LLMModel] = []
            do {
                models = try await fetchModelsUseCase.execute()
            } catch {
                // Continue with empty models — user can still view conversations
            }

            guard case .loaded(var loadedState) = state else { return }
            loadedState.availableModels = models
            state = .loaded(loadedState)
        }
    }

    func reloadConversations() {
        guard case .loaded(var loadedState) = state else { return }
        conversationCloudObserver.start()

        do {
            loadedState.conversations = try loadConversationsUseCase.executeLocally()
            loadedState.errorMessage = nil
            applySearchFilter(&loadedState)
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
            scheduleErrorDismiss()
        }
    }

    func synchronizeAndReloadConversations(scheduleRetry: Bool = true) {
        let result = syncConversationsUseCase.execute()
        reloadConversations()

        guard result == .pendingDownload, scheduleRetry else {
            if result != .pendingDownload {
                cloudRetryTask?.cancel()
                cloudRetryTask = nil
            }
            return
        }
        cloudRetryTask?.cancel()
        cloudRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.synchronizeAndReloadConversations(scheduleRetry: false)
        }
    }
}

// MARK: - Private

private extension ConversationListViewModel {
    func handleConversationEvent(_ event: ConversationEvent) {
        switch event {
        case .tapped(let conversation):
            selectConversation(conversation)
        case .deleted(let id):
            deleteConversation(id)
        case .pinToggled(let id):
            togglePin(id)
        case .tagsUpdated(let id, let tags):
            updateTags(id, tags: tags)
        case .titleEdited(let id, let title):
            renameConversation(id, newTitle: title)
        }
    }

    func handleFilterEvent(_ event: FilterEvent) {
        switch event {
        case .searchChanged(let query):
            updateSearch(query)
        case .tagChanged(let tag):
            updateTagFilter(tag)
        }
    }

    func handleBackupEvent(_ event: BackupEvent) {
        switch event {
        case .exportTapped:
            exportBackup()
        case .dataConsumed:
            clearBackupData()
        case .imported(let data):
            importBackup(data)
        case .resultConsumed:
            clearImportResult()
        case .errorConsumed:
            clearErrorMessage()
        case .readFailed:
            showBackupImportReadError()
        case .exportWriteFailed:
            showBackupExportWriteError()
        }
    }

    func createNewConversation() {
        guard case .loaded(let loadedState) = state else { return }

        let savedModelId = settingsManager.getSelectedModelId()
        let modelId = loadedState.availableModels.first(where: { $0.id == savedModelId })?.id
            ?? loadedState.availableModels.first?.id
            ?? savedModelId
            ?? ""

        let conversation = Conversation(modelId: modelId)
        onConversationSelected?(conversation)
    }

    func selectConversation(_ conversation: Conversation) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.selectedConversation = conversation
        state = .loaded(loadedState)
        onConversationSelected?(conversation)
    }

    func deleteConversation(_ id: UUID) {
        guard case .loaded(var loadedState) = state else { return }

        do {
            try deleteConversationUseCase.execute(id)
            loadedState.conversations.removeAll { $0.id == id }
            if loadedState.selectedConversation?.id == id {
                loadedState.selectedConversation = nil
                onConversationSelected?(nil)
            }
            applySearchFilter(&loadedState)
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
            scheduleErrorDismiss()
        }
    }

    func updateSearch(_ query: String) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.searchQuery = query
        applySearchFilter(&loadedState)
        state = .loaded(loadedState)
    }

    func applySearchFilter(_ loadedState: inout LoadedState) {
        var base = loadedState.conversations

        if let tag = loadedState.activeTagFilter,
           loadedState.conversations.contains(where: { $0.tags.contains(where: { $0.name == tag }) }) {
            base = base.filter { $0.tags.contains(where: { $0.name == tag }) }
        } else {
            loadedState.activeTagFilter = nil
        }

        let query = loadedState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            loadedState.filteredConversations = base
            return
        }

        loadedState.filteredConversations = base.filter { conversation in
            if conversation.title.lowercased().contains(query) {
                return true
            }
            return conversation.messages.contains { message in
                message.content.lowercased().contains(query)
            }
        }
    }

    func togglePin(_ id: UUID) {
        guard case .loaded(var loadedState) = state else { return }
        guard let index = loadedState.conversations.firstIndex(where: { $0.id == id }) else { return }
        let newValue = !loadedState.conversations[index].isPinned
        do {
            try pinConversationUseCase.execute(id, isPinned: newValue)
            loadedState.conversations[index].isPinned = newValue
            applySearchFilter(&loadedState)
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
            scheduleErrorDismiss()
        }
    }

    func updateTags(_ id: UUID, tags: [ConversationTag]) {
        guard case .loaded(var loadedState) = state else { return }
        guard let index = loadedState.conversations.firstIndex(where: { $0.id == id }) else { return }
        do {
            let savedTags = try updateConversationTagsUseCase.execute(id, tags: tags)
            loadedState.conversations[index].tags = savedTags
            applySearchFilter(&loadedState)
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
            scheduleErrorDismiss()
        }
    }

    func updateTagFilter(_ tag: String?) {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.activeTagFilter = tag
        applySearchFilter(&loadedState)
        state = .loaded(loadedState)
    }

    func renameConversation(_ id: UUID, newTitle: String) {
        guard case .loaded(var loadedState) = state else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = loadedState.conversations.firstIndex(where: { $0.id == id }) else { return }
        do {
            try renameConversationUseCase.execute(id, newTitle: trimmed)
            loadedState.conversations[index].title = trimmed
            loadedState.conversations[index].updatedAt = Date()
            applySearchFilter(&loadedState)
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
            scheduleErrorDismiss()
        }
    }

    func exportBackup() {
        guard case .loaded(var loadedState) = state else { return }
        do {
            loadedState.backupData = try exportBackupUseCase.execute()
            loadedState.errorMessage = nil
            state = .loaded(loadedState)
        } catch {
            showError(error, in: &loadedState)
        }
    }

    func clearBackupData() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.backupData = nil
        state = .loaded(loadedState)
    }

    func importBackup(_ data: Data) {
        guard case .loaded(var loadedState) = state else { return }
        do {
            let result = try importConversationsUseCase.execute(data)
            loadedState.conversations = try loadConversationsUseCase.executeLocally()
            loadedState.importResult = result
            loadedState.errorMessage = nil
            applySearchFilter(&loadedState)
            state = .loaded(loadedState)
            NotificationCenter.default.post(name: .conversationDidUpdate, object: nil)
        } catch {
            showError(error, in: &loadedState)
        }
    }

    func clearImportResult() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.importResult = nil
        state = .loaded(loadedState)
    }

    func clearErrorMessage() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.errorMessage = nil
        state = .loaded(loadedState)
    }

    func showBackupImportReadError() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.errorMessage = String(localized: "Unable to read the backup file.")
        state = .loaded(loadedState)
        scheduleErrorDismiss()
    }

    func showBackupExportWriteError() {
        guard case .loaded(var loadedState) = state else { return }
        loadedState.errorMessage = String(localized: "Unable to save the backup file.")
        state = .loaded(loadedState)
        scheduleErrorDismiss()
    }

    func showError(_ error: Error, in loadedState: inout LoadedState) {
        loadedState.errorMessage = error.localizedDescription
        state = .loaded(loadedState)
        scheduleErrorDismiss()
    }

    func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            currentState.errorMessage = nil
            state = .loaded(currentState)
        }
    }
}
