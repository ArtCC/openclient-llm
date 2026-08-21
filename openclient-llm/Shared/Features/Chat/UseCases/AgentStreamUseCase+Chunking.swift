//
//  AgentStreamUseCase+Chunking.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 21/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated extension AgentStreamUseCase {
    func yieldChunked(
        _ text: String,
        as event: @Sendable (String) -> AgentEvent,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation,
        delay: Duration
    ) async throws {
        let maximumChunkCount = 100
        let chunkSize = max(32, (text.count + maximumChunkCount - 1) / maximumChunkCount)
        var index = text.startIndex
        while index < text.endIndex {
            try Task.checkCancellation()
            let end = text.index(index, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            if case .terminated = continuation.yield(event(String(text[index..<end]))) { return }
            index = end
            if index != text.endIndex && delay > Duration.zero {
                try await Task.sleep(for: delay)
            }
        }
    }
}
