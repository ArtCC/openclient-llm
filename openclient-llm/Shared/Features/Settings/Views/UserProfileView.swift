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
    @State private var name: String = ""
    @State private var profileDescription: String = ""
    @State private var extraInfo: String = ""
    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                case .loaded:
                    loadedView()
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
            if case .loaded(let state) = viewModel.state {
                name = state.name
                profileDescription = state.profileDescription
                extraInfo = state.extraInfo
            }
        }
    }
}

// MARK: - Private

private extension UserProfileView {
    func loadedView() -> some View {
        Form {
            nameSection()
            descriptionSection()
            extraInfoSection()
            usageSection()
        }
#if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
#endif
    }

    func nameSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField(String(localized: "Your name"), text: $name, axis: .vertical)
                    .autocorrectionDisabled()
                    .lineLimit(2...)
#if os(iOS)
                    .textInputAutocapitalization(.words)
#endif
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 50 {
                            name = String(newValue.prefix(50))
                        } else {
                            viewModel.send(.nameChanged(newValue))
                        }
                    }
                if !name.isEmpty {
                    characterCountLabel(count: name.count, max: 50)
                }
            }
        } header: {
            Text(String(localized: "Name"))
        } footer: {
            Text(String(localized: "How the assistant will address you. Max 50 characters."))
        }
    }

    func descriptionSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    String(localized: "A brief description about yourself"),
                    text: $profileDescription,
                    axis: .vertical
                )
                .autocorrectionDisabled()
                .lineLimit(3...)
#if os(iOS)
                .textInputAutocapitalization(.sentences)
#endif
                .onChange(of: profileDescription) { _, newValue in
                    if newValue.count > 200 {
                        profileDescription = String(newValue.prefix(200))
                    } else {
                        viewModel.send(.descriptionChanged(newValue))
                    }
                }
                if !profileDescription.isEmpty {
                    characterCountLabel(count: profileDescription.count, max: 200)
                }
            }
        } header: {
            Text(String(localized: "Description"))
        } footer: {
            Text(String(localized: "A brief description about yourself. Max 200 characters."))
        }
    }

    func extraInfoSection() -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    String(localized: "Any additional context for the assistant"),
                    text: $extraInfo,
                    axis: .vertical
                )
                .autocorrectionDisabled()
                .lineLimit(4...)
#if os(iOS)
                .textInputAutocapitalization(.sentences)
#endif
                .onChange(of: extraInfo) { _, newValue in
                    if newValue.count > 500 {
                        extraInfo = String(newValue.prefix(500))
                    } else {
                        viewModel.send(.extraInfoChanged(newValue))
                    }
                }
                if !extraInfo.isEmpty {
                    characterCountLabel(count: extraInfo.count, max: 500)
                }
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
                .foregroundStyle(count >= max ? .red : .secondary)
        }
    }
}

#Preview {
    UserProfileView()
}
