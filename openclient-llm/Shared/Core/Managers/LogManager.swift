//
//  LogManager.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import Foundation

enum LogManager {
    // MARK: - Properties

    enum Level: String {
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
    static func log(
        level: Level,
        message: String,
        file: String,
        function: String,
        line: Int
    ) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let timestamp = Self.dateFormatter.string(from: Date())
        print("[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(function) → \(message)")
        #endif
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
