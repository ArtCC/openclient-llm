//
//  MemoryView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 16/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct MemoryView: View {
    // MARK: - Properties

    @State private var viewModel = MemoryViewModel()
    @State private var isShowingAddSheet = false
    @State private var editingItem: MemoryItem?
    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded(let loadedState):
                    loadedView(loadedState)
                }
            }
            .navigationTitle(String(localized: "Memory"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                MemoryItemEditorView { content in
                    viewModel.send(.addItem(content: content))
                }
            }
            .sheet(item: $editingItem) { item in
                MemoryItemEditorView(initialContent: item.content) { content in
                    viewModel.send(.editItem(id: item.id, content: content))
                }
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension MemoryView {
    func loadedView(_ loadedState: MemoryViewModel.LoadedState) -> some View {
        Group {
            if loadedState.items.isEmpty {
                emptyState
            } else {
                itemsList(loadedState.items)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "No Memory Items"))
                .font(.title3)
                .fontWeight(.semibold)
            Text(String(localized: "Add things you want the assistant to remember across all conversations."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func itemsList(_ items: [MemoryItem]) -> some View {
#if os(macOS)
        List {
            ForEach(items) { item in
                macOSItemRow(item)
            }
        }
#else
        List {
            ForEach(items) { item in
                iOSItemRow(item)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.send(.deleteItem(id: items[index].id))
                }
            }
        }
#endif
    }

#if os(iOS)
    func iOSItemRow(_ item: MemoryItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7.5) {
                Text(item.content)
                    .font(.body)
                    .foregroundStyle(item.isEnabled ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    sourceLabel(item.source)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { _ in viewModel.send(.toggleItem(id: item.id)) }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editingItem = item
            } label: {
                Label(String(localized: "Edit"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.send(.deleteItem(id: item.id))
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }
#endif

#if os(macOS)
    func macOSItemRow(_ item: MemoryItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7.5) {
                Text(item.content)
                    .font(.body)
                    .foregroundStyle(item.isEnabled ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    sourceLabel(item.source)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                editingItem = item
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                viewModel.send(.deleteItem(id: item.id))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { _ in viewModel.send(.toggleItem(id: item.id)) }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
#endif

    func sourceLabel(_ source: MemoryItem.Source) -> some View {
        let label: String
        let icon: String
        let color: Color
        switch source {
        case .user:
            label = String(localized: "You")
            icon = "person.fill"
            color = .blue
        case .model:
            label = String(localized: "Model")
            icon = "brain.head.profile"
            color = .purple
        }

        return HStack(spacing: 3) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption2)
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - MemoryItemEditorView

private struct MemoryItemEditorView: View {
    // MARK: - Properties

    var initialContent: String = ""
    var onSave: (String) -> Void

    @State private var content: String = ""
    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "e.g. User prefers concise answers"),
                        text: $content,
                        axis: .vertical
                    )
                    .lineLimit(4...)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
                } header: {
                    Text(String(localized: "Memory Content"))
                } footer: {
                    Text(String(localized: "This will be injected into every conversation's system prompt."))
                }
            }
#if os(macOS)
            .formStyle(.grouped)
#endif
            .navigationTitle(
                initialContent.isEmpty
                ? String(localized: "New Memory")
                : String(localized: "Edit Memory")
            )
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        onSave(content)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .task {
            content = initialContent
        }
    }
}

#Preview {
    MemoryView()
}
