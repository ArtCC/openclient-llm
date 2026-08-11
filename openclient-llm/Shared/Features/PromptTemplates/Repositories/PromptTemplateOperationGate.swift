//
//  PromptTemplateOperationGate.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 11/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

actor PromptTemplateOperationGate {
    // MARK: - Properties

    static let shared = PromptTemplateOperationGate()

    private var isOccupied = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - Public

    var pendingRequestCount: Int {
        waiters.count
    }

    func perform<Value: Sendable>(
        _ operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> Value {
        await acquire()
        do {
            try Task.checkCancellation()
            let value = try await operation()
            release()
            return value
        } catch {
            release()
            throw error
        }
    }
}

// MARK: - Private

private extension PromptTemplateOperationGate {
    func acquire() async {
        guard isOccupied else {
            isOccupied = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isOccupied = false
            return
        }
        waiters.removeFirst().resume()
    }
}
