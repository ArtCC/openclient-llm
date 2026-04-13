//
//  ConversationListView+macOS.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 12/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

#if os(macOS)
import SwiftUI

extension ConversationListView {
    // MARK: - macOS Toolbar

    @ToolbarContentBuilder
    var macToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            macSearchToolbarItem
        }
        ToolbarItem(placement: .automatic) {
            Button {
                viewModel.send(.refreshTapped)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel(String(localized: "Refresh"))
        }
    }

    var macSearchToolbarItem: some View {
        HStack(spacing: 4) {
            if isMacSearchExpanded {
                TextField(String(localized: "Search conversations..."), text: $macSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .onChange(of: macSearchText) { _, newValue in
                        viewModel.send(.searchChanged(newValue))
                    }
                    .onSubmit {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMacSearchExpanded = false
                        }
                    }
                    .onExitCommand {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMacSearchExpanded = false
                            macSearchText = ""
                            viewModel.send(.searchChanged(""))
                        }
                    }
            }
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isMacSearchExpanded.toggle()
                    if !isMacSearchExpanded {
                        macSearchText = ""
                        viewModel.send(.searchChanged(""))
                    }
                }
            } label: {
                Image(systemName: isMacSearchExpanded ? "xmark.circle.fill" : "magnifyingglass")
            }
            .help(String(localized: "Search"))
        }
    }
}
#endif
