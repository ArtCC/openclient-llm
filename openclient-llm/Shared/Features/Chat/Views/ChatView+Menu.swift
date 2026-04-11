//
//  ChatView+Menu.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - Menu Action

extension ChatView {
    enum MenuAction: Identifiable {
        case export(URL)
        case favourites
        case mediaFiles
        case modelParameters
        case systemPrompt

        var id: String { title }

        var title: String {
            switch self {
            case .export:          return String(localized: "Export")
            case .favourites:      return String(localized: "Favourites")
            case .mediaFiles:      return String(localized: "Media & Files")
            case .modelParameters: return String(localized: "Model Parameters")
            case .systemPrompt:    return String(localized: "System Prompt")
            }
        }

        var systemImage: String {
            switch self {
            case .export:          return "square.and.arrow.up"
            case .favourites:      return "star"
            case .mediaFiles:      return "photo.on.rectangle"
            case .modelParameters: return "slider.horizontal.3"
            case .systemPrompt:    return "text.bubble"
            }
        }
    }
}

// MARK: - Menu Builder

extension ChatView {
    func menuActions(for loadedSt: ChatViewModel.LoadedState) -> [MenuAction] {
        var items: [MenuAction] = []
        if loadedSt.conversation != nil, !loadedSt.messages.isEmpty,
           let url = makeExportURL(loadedSt) {
            items.append(.export(url))
        }
        if !loadedSt.messages.isEmpty {
            items.append(.favourites)
            if loadedSt.messages.contains(where: { !$0.attachments.isEmpty }) {
                items.append(.mediaFiles)
            }
        }
        items.append(.modelParameters)
        items.append(.systemPrompt)
        return items.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
}
