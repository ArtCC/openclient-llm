//
//  CloudFileCoordinator.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 10/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated struct CloudFileCoordinator: Sendable {
    enum CoordinationError: Error {
        case missingResult
    }

    func perform<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await runInBackground(operation)
    }

    func read<Value: Sendable>(
        at url: URL,
        accessor: @escaping @Sendable (URL) throws -> Value
    ) async throws -> Value {
        try await runInBackground {
            try read(at: url, accessor: accessor)
        }
    }

    func write<Value: Sendable>(
        at url: URL,
        options: NSFileCoordinator.WritingOptions = .forReplacing,
        accessor: @escaping @Sendable (URL) throws -> Value
    ) async throws -> Value {
        try await runInBackground {
            try write(at: url, options: options, accessor: accessor)
        }
    }

    func read<Value>(at url: URL, accessor: (URL) throws -> Value) throws -> Value {
        var coordinationError: NSError?
        var result: Result<Value, Error>?
        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            result = Result { try accessor(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CoordinationError.missingResult }
        return try result.get()
    }

    func write<Value>(
        at url: URL,
        options: NSFileCoordinator.WritingOptions = .forReplacing,
        accessor: (URL) throws -> Value
    ) throws -> Value {
        var coordinationError: NSError?
        var result: Result<Value, Error>?
        NSFileCoordinator().coordinate(
            writingItemAt: url,
            options: options,
            error: &coordinationError
        ) { coordinatedURL in
            result = Result { try accessor(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CoordinationError.missingResult }
        return try result.get()
    }

    private func runInBackground<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(with: Result(catching: operation))
            }
        }
    }
}
