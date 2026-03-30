//
//  APIClient.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol APIClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable & Sendable)?
    ) async throws -> T
    func streamRequest(
        endpoint: String,
        body: any Encodable & Sendable
    ) -> AsyncThrowingStream<Data, Error>
}

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

struct APIClient: APIClientProtocol, Sendable {
    // MARK: - Properties

    private let session: URLSession
    private let settingsManager: SettingsManagerProtocol

    // MARK: - Init

    init(
        session: URLSession = .shared,
        settingsManager: SettingsManagerProtocol = SettingsManager()
    ) {
        self.session = session
        self.settingsManager = settingsManager
    }

    // MARK: - Public

    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable & Sendable)? = nil
    ) async throws -> T {
        let urlRequest = try buildRequest(endpoint: endpoint, method: method, body: body)

        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }

    func streamRequest(
        endpoint: String,
        body: any Encodable & Sendable
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try buildRequest(
                        endpoint: endpoint,
                        method: .post,
                        body: body
                    )

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    try validateResponse(response)

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        if payload.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                            break
                        }

                        if let data = payload.data(using: .utf8) {
                            continuation.yield(data)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapError(error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Private

private extension APIClient {
    func buildRequest(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable & Sendable)?
    ) throws -> URLRequest {
        let baseURL = settingsManager.getServerBaseURL()
        guard let url = URL(string: baseURL)?.appendingPathComponent(endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 60

        let apiKey = settingsManager.getAPIKey()
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.networkError(error.localizedDescription)
        }
    }

    func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    func mapError(_ error: Error) -> Error {
        if error is APIError {
            return error
        }
        if let urlError = error as? URLError {
            return APIError.networkError(urlError.localizedDescription)
        }
        return error
    }
}
