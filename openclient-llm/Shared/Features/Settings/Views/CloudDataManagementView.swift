//
//  CloudDataManagementView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct CloudDataManagementView: View {
    // MARK: - Properties

    @State private var viewModel: CloudDataManagementViewModel

    // MARK: - Init

    init(viewModel: CloudDataManagementViewModel = CloudDataManagementViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - View

    var body: some View {
        content
            .navigationTitle(String(localized: "Manage iCloud Data"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .confirmationDialog(
                confirmationTitle,
                isPresented: confirmationBinding,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete"), role: .destructive) {
                    viewModel.send(.deletionConfirmed)
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    viewModel.send(.deletionCancelled)
                }
            } message: {
                Text(confirmationMessage)
            }
            .task {
                viewModel.send(.viewAppeared)
            }
    }
}

// MARK: - Private

private extension CloudDataManagementView {
    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView(String(localized: "Loading iCloud data..."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let loadedState):
            inventoryList(loadedState)
        case .empty:
            unavailableView(
                title: String(localized: "No Synchronized Data"),
                systemImage: "icloud",
                description: String(localized: "There is no synchronized app data in iCloud."),
                showsRetry: true
            )
        case .pending:
            unavailableView(
                title: String(localized: "iCloud Data Is Downloading"),
                systemImage: "icloud.and.arrow.down",
                description: String(
                    localized: "Some iCloud data is still downloading. Try again when it is available."
                ),
                showsRetry: true
            )
        case .unavailable:
            unavailableView(
                title: String(localized: "iCloud Unavailable"),
                systemImage: "icloud.slash",
                description: String(localized: "Your iCloud account or container is not currently available."),
                showsRetry: true
            )
        case .failure:
            unavailableView(
                title: String(localized: "Unable to Load iCloud Data"),
                systemImage: "exclamationmark.triangle",
                description: String(localized: "Your synchronized data could not be safely inspected."),
                showsRetry: true
            )
        }
    }

    func inventoryList(_ loadedState: CloudDataManagementViewModel.LoadedState) -> some View {
        List {
            operationSection
            ForEach(loadedState.sections) { section in
                if !section.items.isEmpty || section.failure != nil {
                    categorySection(section)
                }
            }
            if loadedState.hasInventoryFailures {
                Section {
                    Button(String(localized: "Retry Inventory")) {
                        viewModel.send(.retryInventoryTapped)
                    }
                    .disabled(viewModel.isOperationActive)
                } footer: {
                    Text(String(localized: "Some categories could not be inspected and are not reported as empty."))
                }
            }
            deleteAllSection
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
    }

    @ViewBuilder
    var operationSection: some View {
        switch viewModel.operationState {
        case .idle:
            EmptyView()
        case .deleting:
            Section {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "Deleting synchronized data..."))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Synchronized data deletion"))
                .accessibilityValue(String(localized: "In progress"))
            }
        case .succeeded:
            Section {
                Label(String(localized: "Synchronized data deleted"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(String(localized: "Synchronized data deleted successfully"))
            }
        case .failed:
            Section {
                Label(
                    String(localized: "The deletion could not be completed."),
                    systemImage: "exclamationmark.triangle"
                )
                    .foregroundStyle(.red)
                retryDeletionButton
            }
        case .partiallyFailed(let categories):
            Section {
                Label(String(localized: "Some synchronized data could not be deleted."),
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                ForEach(categories) { category in
                    Text(categoryTitle(category))
                        .accessibilityLabel(String(localized: "Deletion failed for \(categoryTitle(category))"))
                }
                retryDeletionButton
            } header: {
                Text(String(localized: "Deletion Incomplete"))
            } footer: {
                Text(String(localized: "Only the listed categories failed. Retry to finish deleting them."))
            }
        }
    }

    var retryDeletionButton: some View {
        Button(String(localized: "Retry Deletion")) {
            viewModel.send(.retryDeletionTapped)
        }
        .disabled(viewModel.isOperationActive)
    }

    func categorySection(_ section: CloudDataManagementViewModel.CategorySection) -> some View {
        Section {
            if let failure = section.failure {
                Label(inventoryFailureText(failure), systemImage: inventoryFailureImage(failure))
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(categoryTitle(section.category))
                    .accessibilityValue(inventoryFailureText(failure))
            } else {
                ForEach(section.items) { item in
                    itemRow(item)
                }
            }
        } header: {
            Text(categoryTitle(section.category))
        }
    }

    func itemRow(_ item: CloudDataManagementViewModel.Item) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                if case .conversation(let attachmentCount) = item.kind {
                    Text(attachmentDescription(attachmentCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.title)
            .accessibilityValue(itemAccessibilityValue(item))

            Button(role: .destructive) {
                viewModel.send(.deleteRequested(item))
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.isOperationActive)
            .accessibilityLabel(String(localized: "Delete \(item.title)"))
            .accessibilityHint(String(localized: "Deletes this item from iCloud and all synchronized devices."))
#if os(macOS)
            .buttonStyle(.bordered)
#endif
        }
    }

    var deleteAllSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.send(.deleteAllRequested)
            } label: {
                Label(String(localized: "Delete All Synchronized Data"), systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .disabled(viewModel.isOperationActive)
#if os(macOS)
            .buttonStyle(.bordered)
#endif
        } header: {
            Text(String(localized: "All Synchronized Data"))
        } footer: {
            Text(String(localized: "This is separate from Reset App Data, which only resets local app data."))
        }
    }

    func unavailableView(
        title: String,
        systemImage: String,
        description: String,
        showsRetry: Bool
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            if showsRetry {
                Button(String(localized: "Retry")) {
                    viewModel.send(.retryInventoryTapped)
                }
#if os(macOS)
                .buttonStyle(.borderedProminent)
#endif
            }
        }
    }

    var confirmationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.confirmation != nil },
            set: { if !$0 { viewModel.send(.deletionCancelled) } }
        )
    }

    var confirmationTitle: String {
        guard let confirmation = viewModel.confirmation else { return String(localized: "Delete Synchronized Data?") }
        switch confirmation {
        case .item(let item):
            return String(localized: "Delete \(item.title)?")
        case .all:
            return String(localized: "Delete All Synchronized Data?")
        }
    }

    var confirmationMessage: String {
        guard let confirmation = viewModel.confirmation else { return "" }
        switch confirmation {
        case .item(let item):
            if case .conversation = item.kind {
                return String(localized: """
                    Deletes this conversation and its attachments from iCloud and all synchronized devices. \
                    Attachments cannot be deleted independently. This action cannot be undone.
                    """)
            }
            return String(
                localized: "Deletes this item from iCloud and all synchronized devices. This action cannot be undone."
            )
        case .all:
            return String(localized: """
                Deletes these categories from iCloud and all synchronized devices:
                - Conversations and attachments
                - Personal Context
                - Memory
                - Custom Templates

                Newer data created after this deletion can synchronize again. This action cannot be undone.
                """)
        }
    }

    func categoryTitle(_ category: CloudDataManagementViewModel.Category) -> String {
        switch category {
        case .conversations: String(localized: "Conversations")
        case .personalContext: String(localized: "Personal Context")
        case .memory: String(localized: "Memory")
        case .customTemplates: String(localized: "Custom Templates")
        }
    }

    func inventoryFailureText(_ failure: CloudDataManagementViewModel.InventoryFailure) -> String {
        switch failure {
        case .pending: String(localized: "Waiting for iCloud download")
        case .unavailable: String(localized: "Currently unavailable")
        case .error: String(localized: "Could not be safely inspected")
        }
    }

    func inventoryFailureImage(_ failure: CloudDataManagementViewModel.InventoryFailure) -> String {
        switch failure {
        case .pending: "icloud.and.arrow.down"
        case .unavailable: "icloud.slash"
        case .error: "exclamationmark.triangle"
        }
    }

    func attachmentDescription(_ count: Int) -> String {
        count == 1 ? String(localized: "1 attachment") : String(localized: "\(count) attachments")
    }

    func itemAccessibilityValue(_ item: CloudDataManagementViewModel.Item) -> String {
        switch item.kind {
        case .conversation(let count):
            return attachmentDescription(count)
        case .profile:
            return String(localized: "Personal Context")
        case .memory:
            return String(localized: "Memory")
        case .promptTemplate:
            return String(localized: "Custom Template")
        }
    }
}

#Preview {
    NavigationStack {
        CloudDataManagementView(viewModel: CloudDataManagementViewModel(state: .loaded(.init(
            sections: [
                .init(
                    category: .conversations,
                    items: [.init(id: UUID(), title: "Planning", kind: .conversation(attachmentCount: 2))],
                    failure: nil
                ),
                .init(
                    category: .personalContext,
                    items: [.init(id: UUID(), title: "Personal Context", kind: .profile)],
                    failure: nil
                )
            ],
            hasInventoryFailures: false
        ))))
    }
}
