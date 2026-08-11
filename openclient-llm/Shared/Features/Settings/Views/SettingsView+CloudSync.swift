//
//  SettingsView+CloudSync.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

extension SettingsView {
    func cloudSyncSection(_ loadedState: SettingsViewModel.LoadedState) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { loadedState.isCloudSyncEnabled },
                set: { viewModel.send(.cloudSyncToggled($0)) }
            )) {
                Label(String(localized: "iCloud Sync"), systemImage: "icloud")
            }
            .disabled(!loadedState.isCloudAvailable && !loadedState.isCloudSyncEnabled)

            if loadedState.isCloudSyncEnabled {
                Button {
                    synchronizeAppData()
                } label: {
                    HStack(spacing: 8) {
                        if loadedState.isSynchronizing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(loadedState.isSynchronizing
                             ? String(localized: "Synchronizing...")
                             : String(localized: "Sync Now"))
                    }
                }
                .disabled(loadedState.isSynchronizing)
            }

            if !loadedState.isCloudAvailable {
                Label(
                    String(localized: "Sign in to iCloud to enable sync"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "Sync"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(cloudSyncMessages(loadedState.synchronizationResult), id: \.self) { message in
                    Text(message)
                }
            }
        }
    }

    func cloudSyncMessages(_ result: AppSynchronizationResult?) -> [String] {
        guard let result else {
            return [String(
                localized: """
                Sync conversations, personal context, memory, and prompt templates across your devices \
                via iCloud.
                """
            )]
        }

        if result.isSuccessful {
            return [String(
                localized: "Conversations, personal context, memory, and prompt templates are synchronized via iCloud."
            )]
        }

        var messages: [String] = []
        appendSyncMessage(
            to: &messages,
            categories: result.categories(with: .pendingDownload),
            format: String(localized: "Waiting for iCloud downloads: %@.")
        )
        appendSyncMessage(
            to: &messages,
            categories: result.categories(with: .unavailable),
            format: String(localized: "iCloud is unavailable for: %@. Local changes are retained.")
        )
        appendSyncMessage(
            to: &messages,
            categories: result.categories(with: .failed),
            format: String(localized: "Some data could not be synchronized: %@. Local changes are retained.")
        )
        if !result.categories(with: .conflict).isEmpty {
            messages.append(String(localized: "Personal context needs conflict resolution before it can synchronize."))
        }
        return messages
    }
}

// MARK: - Private

private extension SettingsView {
    func appendSyncMessage(
        to messages: inout [String],
        categories: Set<AppSynchronizationResult.Category>,
        format: String
    ) {
        guard !categories.isEmpty else { return }
        messages.append(String(format: format, localizedCategoryList(categories)))
    }

    func localizedCategoryList(_ categories: Set<AppSynchronizationResult.Category>) -> String {
        let names = AppSynchronizationResult.Category.allCases
            .filter(categories.contains)
            .map { category in
                switch category {
                case .conversations:
                    String(localized: "Conversations and attachments")
                case .profile:
                    String(localized: "Personal context")
                case .memory:
                    String(localized: "Memory")
                case .promptTemplates:
                    String(localized: "Prompt templates")
                }
            }
        return ListFormatter.localizedString(byJoining: names)
    }
}
