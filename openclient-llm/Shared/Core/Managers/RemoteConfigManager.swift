//
//  RemoteConfigManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 09/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

typealias RemoteConfigDataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

protocol RemoteConfigManagerProtocol: Sendable {
    func loadConfig() async throws -> RemoteConfig
}

enum RemoteConfigManagerError: Error, Equatable {
    case invalidEndpoint
    case invalidResponse
    case unsupportedSchemaVersion(Int)
}

// Safety: UserDefaults is thread-safe per Apple documentation. The loader is @Sendable.
// All stored properties are immutable (`let`).
final class RemoteConfigManager: RemoteConfigManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    private enum Keys {
        static let cachedConfig = "remoteConfig.cachedConfig"
        static let lastFetchDate = "remoteConfig.lastFetchDate"
    }

    private static var defaultRefreshInterval: TimeInterval {
#if DEBUG
        .zero
#else
        6 * 60 * 60
#endif
    }

    private let endpoint: URL?
    private let dataLoader: RemoteConfigDataLoader
    private let defaults: UserDefaults
    private let refreshInterval: TimeInterval
    private let now: @Sendable () -> Date

    // MARK: - Init

    init(
        endpoint: URL? = Constants.URLs.remoteConfig,
        session: URLSession = .shared,
        dataLoader: RemoteConfigDataLoader? = nil,
        defaults: UserDefaults = .standard,
        refreshInterval: TimeInterval? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.endpoint = endpoint
        self.dataLoader = dataLoader ?? { request in
            try await session.data(for: request)
        }
        self.defaults = defaults
        self.refreshInterval = refreshInterval ?? Self.defaultRefreshInterval
        self.now = now
    }

    // MARK: - Public

    func loadConfig() async throws -> RemoteConfig {
        let cachedConfig = loadCachedConfig()
        if !shouldFetchRemoteConfig(), let cachedConfig {
            LogManager.debug("RemoteConfigManager: Using cached config")
            return cachedConfig
        }

        do {
            return try await fetchRemoteConfig()
        } catch {
            guard let cachedConfig else { throw error }
            LogManager.warning("RemoteConfigManager: Download failed, using cached config")
            return cachedConfig
        }
    }
}

// MARK: - Private

private extension RemoteConfigManager {
    func shouldFetchRemoteConfig() -> Bool {
        guard refreshInterval > .zero else { return true }
        guard let lastFetchDate = defaults.object(forKey: Keys.lastFetchDate) as? Date else { return true }

        let elapsedTime = now().timeIntervalSince(lastFetchDate)
        return elapsedTime < .zero || elapsedTime >= refreshInterval
    }

    func fetchRemoteConfig() async throws -> RemoteConfig {
        guard let endpoint else { throw RemoteConfigManagerError.invalidEndpoint }

        LogManager.network("RemoteConfigManager: Downloading config")

        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, response) = try await dataLoader(request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw RemoteConfigManagerError.invalidResponse
        }

        let config = try JSONDecoder().decode(RemoteConfig.self, from: data)
        guard config.schemaVersion == 1 else {
            throw RemoteConfigManagerError.unsupportedSchemaVersion(config.schemaVersion)
        }

        defaults.set(data, forKey: Keys.cachedConfig)
        defaults.set(now(), forKey: Keys.lastFetchDate)
        LogManager.success("RemoteConfigManager: Config downloaded and cached")
        return config
    }

    func loadCachedConfig() -> RemoteConfig? {
        guard let data = defaults.data(forKey: Keys.cachedConfig),
              let config = try? JSONDecoder().decode(RemoteConfig.self, from: data),
              config.schemaVersion == 1 else {
            return nil
        }
        return config
    }
}
