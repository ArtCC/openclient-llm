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
                        viewModel.send(.save(
                            name: name,
                            description: profileDescription,
                            extraInfo: extraInfo
                        ))
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .task {
            viewModel.send(.viewAppeared)
            if case .loaded(let loadedState) = viewModel.state {
                name = loadedState.name
                profileDescription = loadedState.profileDescription
                extraInfo = loadedState.extraInfo
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            guard case .loaded(let loadedState) = newState else { return }
            // iCloud pushed external changes — refresh local fields only if the user
            // hasn't started editing (local values still match the previous originals).
            guard !hasChanges else { return }
            name = loadedState.name
            profileDescription = loadedState.profileDescription
            extraInfo = loadedState.extraInfo
        }
    }
}

// MARK: - Private

private extension UserProfileView {
    var loadedGroup: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded:
                loadedView()
            }
        }
    }

#if os(macOS)
    var macOSBody: some View {
        VStack(spacing: 0) {
            HStack {
                Button(String(localized: "Cancel")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Text(String(localized: "Personal Context"))
                    .font(.headline)

                Spacer()

                Button(String(localized: "Save")) {
                    viewModel.send(.save(
                        name: name,
                        description: profileDescription,
                        extraInfo: extraInfo
                    ))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!hasChanges)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            loadedGroup
        }
    }
#endif

    var hasChanges: Bool {
        guard case .loaded(let loadedState) = viewModel.state else { return false }
        return name != loadedState.originalName
        || profileDescription != loadedState.originalDescription
        || extraInfo != loadedState.originalExtraInfo
    }

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
#elseif os(macOS)
        .formStyle(.grouped)
#endif
    }

    func nameSection() -> some View {
        let placeholder = name.isEmpty ? String(localized: "Your name") : ""

        return Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField(placeholder, text: $name, axis: .vertical)
                    .multilineTextAlignment(.leading)
                    .autocorrectionDisabled()
                    .lineLimit(2...)
#if os(iOS)
                    .textInputAutocapitalization(.words)
#endif
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 50 {
                            name = String(newValue.prefix(50))
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
        let placeholder = profileDescription.isEmpty ? String(localized: "A brief description about yourself") : ""

        return Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField(placeholder, text: $profileDescription, axis: .vertical)
                    .multilineTextAlignment(.leading)
                    .autocorrectionDisabled()
                    .lineLimit(3...)
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
                    .onChange(of: profileDescription) { _, newValue in
                        if newValue.count > 200 {
                            profileDescription = String(newValue.prefix(200))
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
        let placeholder = extraInfo.isEmpty ? String(localized: "Any additional context for the assistant") : ""

        return Section {
            VStack(alignment: .leading, spacing: 4) {
                TextField(placeholder, text: $extraInfo, axis: .vertical)
                    .multilineTextAlignment(.leading)
                    .autocorrectionDisabled()
                    .lineLimit(4...)
#if os(iOS)
                    .textInputAutocapitalization(.sentences)
#endif
                    .onChange(of: extraInfo) { _, newValue in
                        if newValue.count > 500 {
                            extraInfo = String(newValue.prefix(500))
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
