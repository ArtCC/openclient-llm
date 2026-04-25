//
//  APIClient.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

struct MultipartFileData: Sendable {
    let field: String
    let data: Data
    let fileName: String
    let mimeType: String
}

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
    func multipartRequest<T: Decodable & Sendable>(
        endpoint: String,
        fields: [String: String],
        file: MultipartFileData
    ) async throws -> T
    func rawDataRequest(
        endpoint: String,
        body: any Encodable & Sendable
    ) async throws -> Data
    func searchRequest(
        toolName: String,
        body: LiteLLMSearchRequest
    ) async throws -> LiteLLMSearchResponse
    func fetchSearchTools() async throws -> SearchToolsResponse
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
        LogManager.network("→ \(method.rawValue) /\(endpoint)")

        do {
            let (data, response) = try await performRequest(urlRequest)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                LogManager.error("HTTP \(http.statusCode) /\(endpoint) body: \(String(body.prefix(500)))")
            }
            try validateResponse(response)

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            LogManager.network("← \(method.rawValue) /\(endpoint) [\(statusCode)] \(data.count) bytes")

            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            LogManager.debug("RAW RESPONSE /\(endpoint):\n\(rawBody)")

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)
            } catch {
                LogManager.error("Decoding failed for /\(endpoint): \(error)")
                throw APIError.decodingError
            }
        } catch let error as APIError {
            LogManager.error("Request failed /\(endpoint): \(error.localizedDescription)")
            throw error
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
                    LogManager.network("→ STREAM POST /\(endpoint)")

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    try validateResponse(response)
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    LogManager.network("← STREAM /\(endpoint) [\(statusCode)] opened")

                    var chunkCount = 0
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else {
                            LogManager.debug("Stream cancelled /\(endpoint) after \(chunkCount) chunks")
                            break
                        }

                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        if payload.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                            LogManager.network("← STREAM /\(endpoint) [DONE] — \(chunkCount) chunks received")
                            break
                        }

                        if let data = payload.data(using: .utf8) {
                            chunkCount += 1
                            continuation.yield(data)
                        }
                    }
                    continuation.finish()
                } catch {
                    let mapped = mapError(error)
                    LogManager.error("Stream error /\(endpoint): \(mapped.localizedDescription)")
                    continuation.finish(throwing: mapped)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func multipartRequest<T: Decodable & Sendable>(
        endpoint: String,
        fields: [String: String],
        file: MultipartFileData
    ) async throws -> T {
        LogManager.network("→ MULTIPART POST /\(endpoint) file=\(file.fileName) (\(file.data.count) bytes)")
        let baseURL = settingsManager.getServerBaseURL()
        guard let url = URL(string: baseURL)?.appendingPathComponent(endpoint) else {
            LogManager.error("Invalid URL for multipart /\(endpoint)")
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let apiKey = settingsManager.getAPIKey()
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        for (key, value) in fields {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }

        body.append(Data("--\(boundary)\r\n".utf8))
        let disposition = "Content-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.fileName)\"\r\n"
        body.append(Data(disposition.utf8))
        body.append(Data("Content-Type: \(file.mimeType)\r\n\r\n".utf8))
        body.append(file.data)
        body.append(Data("\r\n".utf8))
        body.append(Data("--\(boundary)--\r\n".utf8))

        request.httpBody = body

        do {
            let (data, response) = try await performRequest(request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                LogManager.error("HTTP \(http.statusCode) /\(endpoint) body: \(String(body.prefix(500)))")
            }
            try validateResponse(response)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            LogManager.network("← MULTIPART /\(endpoint) [\(statusCode)] \(data.count) bytes")

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)
            } catch {
                LogManager.error("Decoding failed for multipart /\(endpoint): \(error)")
                throw APIError.decodingError
            }
        } catch let error as APIError {
            LogManager.error("Multipart request failed /\(endpoint): \(error.localizedDescription)")
            throw error
        }
    }

    func searchRequest(
        toolName: String,
        body: LiteLLMSearchRequest
    ) async throws -> LiteLLMSearchResponse {
        let endpoint = "v1/search/\(toolName)"
        return try await request(endpoint: endpoint, method: .post, body: body)
    }

    func fetchSearchTools() async throws -> SearchToolsResponse {
        try await request(endpoint: "v1/search/tools", method: .get, body: nil)
    }

    func rawDataRequest(
        endpoint: String,
        body: any Encodable & Sendable
    ) async throws -> Data {
        let urlRequest = try buildRequest(endpoint: endpoint, method: .post, body: body)
        LogManager.network("→ POST /\(endpoint) (raw data)")

        do {
            let (data, response) = try await performRequest(urlRequest)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                LogManager.error("HTTP \(http.statusCode) /\(endpoint) body: \(String(body.prefix(500)))")
            }
            try validateResponse(response)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            LogManager.network("← POST /\(endpoint) [\(statusCode)] \(data.count) bytes")
            return data
        } catch let error as APIError {
            LogManager.error("Raw request failed /\(endpoint): \(error.localizedDescription)")
            throw error
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
            throw mapURLError(error)
        }
    }

    func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            LogManager.error("Invalid response — not an HTTPURLResponse")
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            LogManager.warning("HTTP 401 Unauthorized")
            throw APIError.unauthorized
        case 429:
            LogManager.warning("HTTP 429 Rate Limited")
            throw APIError.rateLimited
        default:
            LogManager.error("HTTP \(httpResponse.statusCode) error")
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    func mapError(_ error: Error) -> Error {
        if error is APIError {
            return error
        }
        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }
        return error
    }

    func mapURLError(_ error: URLError) -> APIError {
        LogManager.error("URLError \(error.code.rawValue): \(error.localizedDescription)")
        switch error.code {
        case .cannotFindHost, .dnsLookupFailed:
            return .networkError(String(localized: "Could not find the server. Please check the URL."))
        case .cannotConnectToHost:
            return .networkError(String(localized: "Could not connect to the server."))
        case .notConnectedToInternet:
            return .networkError(String(localized: "No internet connection. Please check your network."))
        case .timedOut:
            return .networkError(String(localized: "The request timed out. The server may be slow or unreachable."))
        case .networkConnectionLost:
            return .networkError(String(localized: "The network connection was lost."))
        case .secureConnectionFailed:
            return .networkError(String(localized: "Could not establish a secure connection to the server."))
        case .serverCertificateUntrusted, .serverCertificateHasBadDate,
            .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
            return .networkError(String(localized: "The server certificate is not trusted."))
        case .cancelled:
            return .networkError(String(localized: "The request was cancelled."))
        default:
            return .networkError(String(localized: "A network error occurred. Please try again."))
        }
    }
}
