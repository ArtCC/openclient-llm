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

    // MARK: - Init

    init(
        state: State = .loading,
        loadTemplatesUseCase: LoadPromptTemplatesUseCaseProtocol = LoadPromptTemplatesUseCase(),
        saveTemplateUseCase: SavePromptTemplateUseCaseProtocol = SavePromptTemplateUseCase(),
        deleteTemplateUseCase: DeletePromptTemplateUseCaseProtocol = DeletePromptTemplateUseCase()
    ) {
        self.state = state
        self.loadTemplatesUseCase = loadTemplatesUseCase
        self.saveTemplateUseCase = saveTemplateUseCase
        self.deleteTemplateUseCase = deleteTemplateUseCase
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
        do {
            let all = try loadTemplatesUseCase.execute()
            let builtIns = all.filter(\.isBuiltIn).sorted { $0.title < $1.title }
            let custom = all.filter { !$0.isBuiltIn }.sorted { $0.title < $1.title }
            state = .loaded(.init(builtInTemplates: builtIns, customTemplates: custom))
        } catch {
            state = .loaded(.init(builtInTemplates: [], customTemplates: [], errorMessage: error.localizedDescription))
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
                createdAt: editing.createdAt
            )
        } else {
            template = PromptTemplate(title: title, content: content)
        }
        do {
            try saveTemplateUseCase.execute(template)
            loadTemplates()
        } catch {
            if case .loaded(var loadedState) = state {
                loadedState.errorMessage = error.localizedDescription
                state = .loaded(loadedState)
            }
        }
    }

    func deleteTemplate(_ template: PromptTemplate) {
        guard !template.isBuiltIn else { return }
        do {
            try deleteTemplateUseCase.execute(template.id)
            loadTemplates()
        } catch {
            if case .loaded(var loadedState) = state {
                loadedState.errorMessage = error.localizedDescription
                state = .loaded(loadedState)
            }
        }
    }
}
