//
//  LogManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

nonisolated enum LogManager {
    // MARK: - Properties

    enum Level: String, Sendable {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case network = "🌐 NETWORK"
        case success = "✅ SUCCESS"
    }

    // MARK: - Public

    static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }

    static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }

    static func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }

    static func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }

    static func network(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .network, message: message, file: file, function: function, line: line)
    }

    static func success(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .success, message: message, file: file, function: function, line: line)
    }
}

// MARK: - Private

private extension LogManager {
    nonisolated static func log(
        level: Level,
        message: String,
        file: String,
        function: String,
        line: Int
    ) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let timestamp = makeTimestamp()
        print("[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(function) → \(message)")
        #endif
    }

    nonisolated static func makeTimestamp() -> String {
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: Date())
        return String(
            format: "%02d:%02d:%02d.%03d",
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0,
            (components.nanosecond ?? 0) / 1_000_000
        )
    }
}
