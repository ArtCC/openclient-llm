//
//  ChatFavouritesView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct ChatFavouritesView: View {
    // MARK: - Properties

    let messages: [ChatMessage]
    var onMessageSelected: ((UUID) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var favourites: [ChatMessage] {
        messages.filter(\.isFavourite)
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                if favourites.isEmpty {
                    emptyState
                } else {
                    favouritesList
                }
            }
            .navigationTitle(String(localized: "Favourites"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Private

private extension ChatFavouritesView {
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(String(localized: "No Favourites Yet"))
                .font(.headline)
                .foregroundStyle(.primary)
            Text(String(localized: "Long-press any message and tap \"Add to Favourites\" to save it here."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var favouritesList: some View {
        List(favourites) { message in
            Button {
                dismiss()
                onMessageSelected?(message.id)
            } label: {
                favouriteRow(message)
            }
            .buttonStyle(.plain)
        }
    }

    func favouriteRow(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: message.role == .user ? "person.fill" : "sparkles")
                    .font(.caption2)
                    .foregroundStyle(message.role == .user ? Color.appAccent : .secondary)
                Text(message.role == .user
                     ? String(localized: "You")
                     : String(localized: "Assistant"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(message.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !message.content.isEmpty {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            } else if !message.attachments.isEmpty {
                Label(String(localized: "\(message.attachments.count) attachment(s)"),
                      systemImage: "paperclip")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ChatFavouritesView(
        messages: [
            ChatMessage(
                role: .user,
                content: "How do I reverse a string in Swift?",
                isFavourite: true
            ),
            ChatMessage(
                role: .assistant,
                content: "You can use `String(string.reversed())` to reverse a Swift string.",
                isFavourite: true
            )
        ]
    )
}
