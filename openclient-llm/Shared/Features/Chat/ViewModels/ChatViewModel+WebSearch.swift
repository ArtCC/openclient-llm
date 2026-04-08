//
//  ChatViewModel+WebSearch.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 05/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

// MARK: - Web Search helpers

extension ChatViewModel {
    func toggleWebSearch() {
        guard case .loaded(var loadedState) = state else { return }
        let newValue = !loadedState.isWebSearchEnabled
        setWebSearchEnabledUseCase.execute(newValue)
        loadedState.isWebSearchEnabled = newValue
        state = .loaded(loadedState)
        LogManager.debug("webSearch toggled: \(newValue)")
    }
}
