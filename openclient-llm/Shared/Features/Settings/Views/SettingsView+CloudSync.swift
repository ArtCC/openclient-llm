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
        let status = viewModel.cloudSyncStatus
        let presentation = CloudSyncStatusPresentation.make(
            for: status,
            lastSuccessfulSyncAt: viewModel.lastSuccessfulCloudSyncAt
        )
        return Section {
            Toggle(isOn: Binding(
                get: { loadedState.isCloudSyncEnabled },
                set: { viewModel.send(.cloudSyncToggled($0)) }
            )) {
                Label(String(localized: "iCloud Sync"), systemImage: "icloud")
            }

            cloudSyncStatusRow(presentation)

            if loadedState.isCloudSyncEnabled {
                cloudSyncAction(presentation)
            }

            NavigationLink {
                CloudDataManagementView()
            } label: {
                Label(String(localized: "Manage iCloud Data"), systemImage: "externaldrive.badge.icloud")
            }
            .accessibilityHint(String(localized: "Review and delete data stored in iCloud."))
        } header: {
            Text(String(localized: "Sync"))
        } footer: {
            Text(String(
                localized: """
                Synchronizes conversations and their attachments, profile, memory, and prompt templates across \
                devices. Attachments are synchronized as part of their conversations.
                """
            ))
        }
    }
}

// MARK: - Private

private extension SettingsView {
    func cloudSyncStatusRow(_ presentation: CloudSyncStatusPresentation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if presentation.showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: presentation.systemImage)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                if let detail = presentation.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([presentation.title, presentation.detail].compactMap { $0 }.joined(separator: ". "))
    }

    @ViewBuilder
    func cloudSyncAction(_ presentation: CloudSyncStatusPresentation) -> some View {
        if presentation.canRetry {
            Button(presentation.requiresAccountReview
                   ? String(localized: "Review iCloud Account")
                   : String(localized: "Retry")) {
                viewModel.send(.cloudSyncRetryTapped)
            }
            .accessibilityHint(presentation.requiresAccountReview
                               ? String(localized: "Review the current account before enabling synchronization.")
                               : String(localized: "Retry iCloud synchronization."))
#if os(macOS)
            .buttonStyle(.borderedProminent)
#endif
        } else {
            Button(String(localized: "Sync Now")) {
                synchronizeAppData()
            }
            .disabled(presentation.showsProgress)
#if os(macOS)
            .buttonStyle(.bordered)
#endif
        }
    }
}
