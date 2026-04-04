//
//  ChatView+ModelSelector.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 03/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

// MARK: - Model Selector

extension ChatView {
    @ViewBuilder
    func modelSelector(using viewModel: ChatViewModel) -> some View {
        if case .loaded(let loadedState) = viewModel.state,
           !loadedState.availableModels.isEmpty {
            Menu {
                ForEach(loadedState.availableModels) { model in
                    Button {
                        viewModel.send(.modelSelected(model))
                    } label: {
                        HStack {
                            Text(model.id)
                            if model == loadedState.selectedModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(
                        loadedState.selectedModel?.id
                        ?? String(localized: "No Model")
                    )
                    .font(.poppins(.semiBold, size: 17, relativeTo: .headline))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 200)

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
