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
        case refreshTapped
        case conversationTapped(Conversation)
        case deleteConversation(UUID)
        case searchChanged(String)
        case pinToggled(UUID)
        case tagsUpdated(UUID, [String])
        case tagFilterChanged(String?)
        case titleEdited(UUID, String)
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

        var allTags: [String] {
            let tagSet = conversations.flatMap(\.tags)
            return Array(Set(tagSet)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
    private let settingsManager: SettingsManagerProtocol
    private var errorDismissTask: Task<Void, Never>?

    var onConversationSelected: ((Conversation?) -> Void)?

    // MARK: - Init

    init(
        state: State = .loading,
        loadConversationsUseCase: LoadConversationsUseCaseProtocol = LoadConversationsUseCase(),
        deleteConversationUseCase: DeleteConversationUseCaseProtocol = DeleteConversationUseCase(),
        pinConversationUseCase: PinConversationUseCaseProtocol = PinConversationUseCase(),
        updateConversationTagsUseCase: UpdateConversationTagsUseCaseProtocol = UpdateConversationTagsUseCase(),
        renameConversationUseCase: RenameConversationUseCaseProtocol = RenameConversationUseCase(),
        fetchModelsUseCase: FetchModelsUseCaseProtocol = FetchModelsUseCase(),
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.state = state
        self.loadConversationsUseCase = loadConversationsUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
        self.pinConversationUseCase = pinConversationUseCase
        self.updateConversationTagsUseCase = updateConversationTagsUseCase
        self.renameConversationUseCase = renameConversationUseCase
        self.fetchModelsUseCase = fetchModelsUseCase
        self.settingsManager = settingsManager
        observeAppDataReset()
        observeConversationUpdated()
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadData()
        case .newConversationTapped:
            createNewConversation()
        case .refreshTapped:
            refresh()
        case .conversationTapped(let conversation):
            selectConversation(conversation)
        case .deleteConversation(let id):
            deleteConversation(id)
        case .searchChanged(let query):
            updateSearch(query)
        case .pinToggled(let id):
            togglePin(id)
        case .tagsUpdated(let id, let tags):
            updateTags(id, tags: tags)
        case .tagFilterChanged(let tag):
            updateTagFilter(tag)
        case .titleEdited(let id, let newTitle):
            renameConversation(id, newTitle: newTitle)
        }
    }

    func refresh() {
        reloadConversations()
    }

    func refreshAsync() async {
        reloadConversations()
        await Task.yield()
    }
}

// MARK: - Private

private extension ConversationListViewModel {
    func loadData() {
        state = .loading

        Task {
            var models: [LLMModel] = []
            do {
                models = try await fetchModelsUseCase.execute()
            } catch {
                // Continue with empty models — user can still view conversations
            }

            do {
                let conversations = try loadConversationsUseCase.execute()
                state = .loaded(LoadedState(
                    conversations: conversations,
                    availableModels: models,
                    filteredConversations: conversations
                ))
            } catch {
                state = .loaded(LoadedState(
                    availableModels: models,
                    errorMessage: error.localizedDescription
                ))
                scheduleErrorDismiss()
            }
        }
    }

    func reloadConversations() {
        guard case .loaded(var loadedState) = state else { return }

        do {
            loadedState.conversations = try loadConversationsUseCase.execute()
            loadedState.errorMessage = nil
            applySearchFilter(&loadedState)
            state = .loaded(loadedState)
        } catch {
            loadedState.errorMessage = error.localizedDescription
            state = .loaded(loadedState)
            scheduleErrorDismiss()
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

        if let tag = loadedState.activeTagFilter {
            base = base.filter { $0.tags.contains(tag) }
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

    func updateTags(_ id: UUID, tags: [String]) {
        guard case .loaded(var loadedState) = state else { return }
        guard let index = loadedState.conversations.firstIndex(where: { $0.id == id }) else { return }
        do {
            try updateConversationTagsUseCase.execute(id, tags: tags)
            loadedState.conversations[index].tags = tags
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

    func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, case .loaded(var currentState) = state else { return }
            currentState.errorMessage = nil
            state = .loaded(currentState)
        }
    }

    func observeAppDataReset() {
        Task { [weak self] in
            let notifications = NotificationCenter.default
                .notifications(named: .appDataDidReset)
            for await _ in notifications {
                guard let self else { return }
                await MainActor.run { self.loadData() }
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
}
