//
//  PromptTemplatesView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 04/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct PromptTemplatesView: View {
    // MARK: - Properties

    let onSelect: (PromptTemplate) -> Void

    @State private var viewModel = PromptTemplatesViewModel()
    @State private var showEditor = false
    @State private var editingTemplate: PromptTemplate?

    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        Group {
#if os(macOS)
            macOSBody
#else
            NavigationStack {
                content
                    .navigationTitle(String(localized: "Prompt Library"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Cancel")) {
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                editingTemplate = nil
                                showEditor = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
            }
#endif
        }
        .sheet(isPresented: $showEditor) {
            PromptTemplateEditorView(editingTemplate: editingTemplate) { title, content in
                viewModel.send(.saveTapped(title: title, content: content, editingTemplate: editingTemplate))
                editingTemplate = nil
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
#if os(macOS)
        .frame(width: 480, height: 520)
#endif
    }
}

// MARK: - Private

private extension PromptTemplatesView {
#if os(macOS)
    var macOSBody: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Text(String(localized: "Prompt Library"))
                    .font(.headline)

                Spacer()

                Button(String(localized: "Done")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            content
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            editingTemplate = nil
                            showEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
        }
    }
#endif

    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let loadedState):
            if loadedState.builtInTemplates.isEmpty && loadedState.customTemplates.isEmpty {
                emptyState
            } else {
                templateList(loadedState: loadedState)
            }
        }
    }

    var emptyState: some View {
        ContentUnavailableView(
            String(localized: "No Templates"),
            systemImage: "doc.text",
            description: Text(String(localized: "Tap + to create your first custom prompt template."))
        )
    }

    func templateList(loadedState: PromptTemplatesViewModel.LoadedState) -> some View {
        List {
            if !loadedState.builtInTemplates.isEmpty {
                Section(String(localized: "Built-in")) {
                    ForEach(loadedState.builtInTemplates) { template in
                        templateRow(template)
                    }
                }
            }
            if !loadedState.customTemplates.isEmpty {
                Section(String(localized: "Custom")) {
                    ForEach(loadedState.customTemplates) { template in
                        templateRow(template)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.send(.deleteTapped(template))
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                                Button {
                                    editingTemplate = template
                                    showEditor = true
                                } label: {
                                    Label(String(localized: "Edit"), systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
    }

    func templateRow(_ template: PromptTemplate) -> some View {
        Button {
            onSelect(template)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if template.isBuiltIn {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(template.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PromptTemplatesView { _ in }
}
