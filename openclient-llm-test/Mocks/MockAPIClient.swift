//
//  MockAPIClient.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation
@testable import openclient_llm

// Safety: Only used within serialized @MainActor test methods.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    // MARK: - Properties

    var requestResult: Any?
    var requestError: Error?
    var streamChunks: [Data] = []
    var streamError: Error?
    var multipartResult: Any?
    var multipartError: Error?
    var rawDataResult: Data?
    var rawDataError: Error?

    // MARK: - Public

    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable & Sendable)?
    ) async throws -> T {
        if let error = requestError {
            throw error
        }
        guard let result = requestResult as? T else {
            throw APIError.decodingError
        }
        return result
    }

    func streamRequest(
        endpoint: String,
        body: any Encodable & Sendable
    ) -> AsyncThrowingStream<Data, Error> {
        let chunks = streamChunks
        let error = streamError
        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    func multipartRequest<T: Decodable & Sendable>(
        endpoint: String,
        fields: [String: String],
        file: MultipartFileData
    ) async throws -> T {
        if let error = multipartError {
            throw error
        }
        guard let result = multipartResult as? T else {
            throw APIError.decodingError
        }
        return result
    }

    func rawDataRequest(
        endpoint: String,
        body: any Encodable & Sendable
    ) async throws -> Data {
        if let error = rawDataError {
            throw error
        }
        return rawDataResult ?? Data()
    }
}
