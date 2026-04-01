//
//  UserProfileView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct UserProfileView: View {
    // MARK: - Properties

    @State private var viewModel = UserProfileViewModel()
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
            .navigationTitle(String(localized: "Personal Context"))
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
                        viewModel.send(.saveTapped)
                        dismiss()
                    }
                    .disabled(!viewModel.hasChanges)
                }
            }
        }
        .task {
            viewModel.send(.viewAppeared)
        }
    }
}

// MARK: - Private

private extension UserProfileView {
    func loadedView(_ loadedState: UserProfileViewModel.LoadedState) -> some View {
        Form {
            nameSection(loadedState)
            descriptionSection(loadedState)
            extraInfoSection(loadedState)
            usageSection()
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
#endif
    }

    func nameSection(_ loadedState: UserProfileViewModel.LoadedState) -> some View {
        Section {
            TextField(String(localized: "Your name"), text: Binding(
                get: { loadedState.name },
                set: { viewModel.send(.nameChanged($0)) }
            ))
            .autocorrectionDisabled()
#if os(iOS)
            .textInputAutocapitalization(.words)
#endif

            if !loadedState.name.isEmpty {
                characterCountLabel(count: loadedState.name.count, max: 50)
            }
        } header: {
            Text(String(localized: "Name"))
        } footer: {
            Text(String(localized: "How the assistant will address you. Max 50 characters."))
        }
    }

    func descriptionSection(_ loadedState: UserProfileViewModel.LoadedState) -> some View {
        Section {
#if os(iOS)
            TextEditor(text: Binding(
                get: { loadedState.profileDescription },
                set: { viewModel.send(.descriptionChanged($0)) }
            ))
            .frame(minHeight: 80)
            .autocorrectionDisabled()
#else
            TextEditor(text: Binding(
                get: { loadedState.profileDescription },
                set: { viewModel.send(.descriptionChanged($0)) }
            ))
            .frame(minHeight: 80)
#endif

            if !loadedState.profileDescription.isEmpty {
                characterCountLabel(count: loadedState.profileDescription.count, max: 200)
            }
        } header: {
            Text(String(localized: "Description"))
        } footer: {
            Text(String(localized: "A brief description about yourself. Max 200 characters."))
        }
    }

    func extraInfoSection(_ loadedState: UserProfileViewModel.LoadedState) -> some View {
        Section {
#if os(iOS)
            TextEditor(text: Binding(
                get: { loadedState.extraInfo },
                set: { viewModel.send(.extraInfoChanged($0)) }
            ))
            .frame(minHeight: 100)
            .autocorrectionDisabled()
#else
            TextEditor(text: Binding(
                get: { loadedState.extraInfo },
                set: { viewModel.send(.extraInfoChanged($0)) }
            ))
            .frame(minHeight: 100)
#endif

            if !loadedState.extraInfo.isEmpty {
                characterCountLabel(count: loadedState.extraInfo.count, max: 500)
            }
        } header: {
            Text(String(localized: "Extra Info"))
        } footer: {
            Text(String(localized: "Any additional context you want the assistant to know. Max 500 characters."))
        }
    }

    func usageSection() -> some View {
        let info = String(
            localized: "This information is added to every conversation so models can personalise their responses."
        )
        return Section {
            Label(info, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    func characterCountLabel(count: Int, max: Int) -> some View {
        HStack {
            Spacer()
            Text("\(count)/\(max)")
                .font(.caption2)
                .foregroundStyle(count > max ? .red : .secondary)
        }
    }
}

#Preview {
    UserProfileView()
}
