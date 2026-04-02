//
//  ConversationTagsView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ConversationTagsView: View {
    // MARK: - Properties

    let conversationTitle: String
    let existingTags: [String]
    let onSave: ([String]) -> Void

    @State private var tags: [String]
    @State private var newTagText: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    // MARK: - Init

    init(conversationTitle: String, existingTags: [String], onSave: @escaping ([String]) -> Void) {
        self.conversationTitle = conversationTitle
        self.existingTags = existingTags
        self.onSave = onSave
        _tags = State(initialValue: existingTags)
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(String(localized: "Add tag..."), text: $newTagText)
                            .focused($isFieldFocused)
                            .autocorrectionDisabled()
#if os(iOS)
                            .textInputAutocapitalization(.never)
#endif
                            .onSubmit { addTag() }

                        Button(String(localized: "Add")) {
                            addTag()
                        }
                        .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text(String(localized: "New Tag"))
                }

                if !tags.isEmpty {
                    Section {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(.secondary)
                                Text(tag)
                                Spacer()
                            }
                        }
                        .onDelete { indexSet in
                            tags.remove(atOffsets: indexSet)
                        }
                    } header: {
                        Text(String(localized: "Tags"))
                    } footer: {
                        Text(String(localized: "Swipe left to remove a tag."))
                    }
                }
            }
#if os(macOS)
            .formStyle(.grouped)
#endif
            .navigationTitle(conversationTitle.isEmpty ? String(localized: "Tags") : conversationTitle)
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
                        onSave(tags)
                        dismiss()
                    }
                }
            }
        }
#if os(macOS)
        .frame(width: 480, height: 400)
#endif
    }
}

// MARK: - Private

private extension ConversationTagsView {
    func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTagText = ""
    }
}

#Preview {
    ConversationTagsView(
        conversationTitle: "My conversation",
        existingTags: ["swift", "ai"]
    ) { _ in }
}
