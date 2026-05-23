//
//  CrateTelemetry.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import Foundation
import OSLog

enum CrateTelemetry {
    static let subsystem = Bundle.main.bundleIdentifier ?? "Crate"
    static let performance = Logger(subsystem: subsystem, category: "Performance")
    static let images = Logger(subsystem: subsystem, category: "Images")

    static func measure<T>(
        _ label: String,
        details: @autoclosure () -> String = "",
        operation: () throws -> T
    ) rethrows -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        do {
            let result = try operation()
            log(label: label, status: "ok", startedAt: start, details: details())
            return result
        } catch {
            log(label: label, status: "error", startedAt: start, details: details())
            throw error
        }
    }

    static func measureAsync<T: Sendable>(
        _ label: String,
        details: String = "",
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        do {
            let result = try await operation()
            log(label: label, status: "ok", startedAt: start, details: details)
            return result
        } catch {
            log(label: label, status: "error", startedAt: start, details: details)
            throw error
        }
    }

    private static func log(label: String, status: String, startedAt: UInt64, details: String) {
        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
        let elapsedText = String(format: "%.1f", elapsedMilliseconds)
        if details.isEmpty {
            performance.debug("\(label, privacy: .public) \(status, privacy: .public) \(elapsedText, privacy: .public)ms")
        } else {
            performance.debug("\(label, privacy: .public) \(status, privacy: .public) \(elapsedText, privacy: .public)ms \(details, privacy: .public)")
        }
    }
}
