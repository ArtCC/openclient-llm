//
//  ChatView+URLScheme.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 18/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - URL Scheme

extension ChatView {
    func processURLSchemeTextIfNeeded(
        viewModel: ChatViewModel,
        urlSchemeText: String?,
        onURLSchemeTextProcessed: (() -> Void)?
    ) async {
        guard let text = urlSchemeText, !text.isEmpty else { return }

        // Wait until ChatViewModel finishes loading before sending input.
        for _ in 0..<60 {
            if case .loaded = viewModel.state { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard case .loaded = viewModel.state else { return }

        viewModel.send(.inputChanged(text))
        onURLSchemeTextProcessed?()
    }
}
