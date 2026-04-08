//
//  OnboardingRepository.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 30/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

protocol OnboardingRepositoryProtocol: Sendable {
    func testConnection(serverURL: String, apiKey: String) async throws
    func checkLiteLLMHealth(serverURL: String) async -> Bool
}

struct OnboardingRepository: OnboardingRepositoryProtocol {
    // MARK: - Properties

    private let session: URLSession

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    func testConnection(serverURL: String, apiKey: String) async throws {
        guard let url = URL(string: serverURL)?.appendingPathComponent("models") else {
            throw OnboardingRepositoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OnboardingRepositoryError.serverUnreachable
        }
    }

    func checkLiteLLMHealth(serverURL: String) async -> Bool {
        guard !serverURL.isEmpty,
              let url = URL(string: serverURL)?.appendingPathComponent("health/readiness") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }

            return json["litellm_version"] != nil
        } catch {
            return false
        }
    }
}

// MARK: - OnboardingRepositoryError

enum OnboardingRepositoryError: LocalizedError, Sendable {
    case invalidURL
    case serverUnreachable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "The server URL is not valid.")
        case .serverUnreachable:
            String(localized: "The server is not reachable.")
        }
    }
}
