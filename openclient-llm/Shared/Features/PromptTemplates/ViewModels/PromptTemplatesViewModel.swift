//
//  PromptTemplatesViewModel.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

@Observable
@MainActor
final class PromptTemplatesViewModel {
    // MARK: - Properties

    enum Event {
        case viewAppeared
        case saveTapped(title: String, content: String, editingTemplate: PromptTemplate?)
        case deleteTapped(PromptTemplate)
    }

    enum State: Equatable {
        case loading
        case loaded(LoadedState)
    }

    struct LoadedState: Equatable {
        var builtInTemplates: [PromptTemplate]
        var customTemplates: [PromptTemplate]
        var errorMessage: String?
    }

    private(set) var state: State

    private let loadTemplatesUseCase: LoadPromptTemplatesUseCaseProtocol
    private let saveTemplateUseCase: SavePromptTemplateUseCaseProtocol
    private let deleteTemplateUseCase: DeletePromptTemplateUseCaseProtocol
    private let appReviewManager: AppReviewManagerProtocol
    private let notificationCenter: NotificationCenter
    private var cloudSyncTask: Task<Void, Never>?

    // MARK: - Init

    init(
        state: State = .loading,
        loadTemplatesUseCase: LoadPromptTemplatesUseCaseProtocol = LoadPromptTemplatesUseCase(),
        saveTemplateUseCase: SavePromptTemplateUseCaseProtocol = SavePromptTemplateUseCase(),
        deleteTemplateUseCase: DeletePromptTemplateUseCaseProtocol = DeletePromptTemplateUseCase(),
        appReviewManager: AppReviewManagerProtocol = AppReviewManager(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.state = state
        self.loadTemplatesUseCase = loadTemplatesUseCase
        self.saveTemplateUseCase = saveTemplateUseCase
        self.deleteTemplateUseCase = deleteTemplateUseCase
        self.appReviewManager = appReviewManager
        self.notificationCenter = notificationCenter
        startObservingCloudChanges()
    }

    isolated deinit {
        cloudSyncTask?.cancel()
    }

    // MARK: - Input functions

    func send(_ event: Event) {
        switch event {
        case .viewAppeared:
            loadTemplates()
        case .saveTapped(let title, let content, let editingTemplate):
            saveTemplate(title: title, content: content, editingTemplate: editingTemplate)
        case .deleteTapped(let template):
            deleteTemplate(template)
        }
    }
}

// MARK: - Private

private extension PromptTemplatesViewModel {
    func loadTemplates() {
        Task {
            do {
                let all = try await loadTemplatesUseCase.execute()
                let builtIns = all.filter(\.isBuiltIn).sorted { $0.title < $1.title }
                let custom = all.filter { !$0.isBuiltIn }.sorted { $0.title < $1.title }
                state = .loaded(.init(builtInTemplates: builtIns, customTemplates: custom))
            } catch {
                state = .loaded(.init(
                    builtInTemplates: [],
                    customTemplates: [],
                    errorMessage: error.localizedDescription
                ))
            }
        }
    }

    func startObservingCloudChanges() {
        cloudSyncTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.notificationCenter.notifications(
                named: .promptTemplatesDidChangeExternally
            ) {
                guard !Task.isCancelled else { break }
                self.loadTemplates()
            }
        }
    }

    func saveTemplate(title: String, content: String, editingTemplate: PromptTemplate?) {
        let template: PromptTemplate
        if let editing = editingTemplate {
            template = PromptTemplate(
                id: editing.id,
                title: title,
                content: content,
                isBuiltIn: false,
                createdAt: editing.createdAt,
                updatedAt: Date()
            )
        } else {
            template = PromptTemplate(title: title, content: content)
        }
        Task {
            do {
                try await saveTemplateUseCase.execute(template)
                if editingTemplate == nil {
                    appReviewManager.requestReview()
                }
                loadTemplates()
            } catch {
                if case .loaded(var loadedState) = state {
                    loadedState.errorMessage = error.localizedDescription
                    state = .loaded(loadedState)
                }
            }
        }
    }

    func deleteTemplate(_ template: PromptTemplate) {
        guard !template.isBuiltIn else { return }
        Task {
            do {
                try await deleteTemplateUseCase.execute(template.id)
                loadTemplates()
            } catch {
                if case .loaded(var loadedState) = state {
                    loadedState.errorMessage = error.localizedDescription
                    state = .loaded(loadedState)
                }
            }
        }
    }
}
