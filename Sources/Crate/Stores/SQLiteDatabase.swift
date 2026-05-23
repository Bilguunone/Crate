//
//  SQLiteDatabase.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-22.
//

import Foundation
import SQLite3

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): "Could not open database: \(message)"
        case .prepareFailed(let message): "Could not prepare SQL: \(message)"
        case .stepFailed(let message): "Could not run SQL: \(message)"
        case .bindFailed(let message): "Could not bind SQL value: \(message)"
        }
    }
}

final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(url: URL) throws {
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw DatabaseError.openFailed(Self.message(db))
        }
        sqlite3_busy_timeout(db, 5_000)
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    deinit {
        sqlite3_close(db)
    }

    func execute(_ sql: String, values: [SQLiteValue] = []) throws {
        let statement = try prepare(sql, values: values)
        defer { sqlite3_finalize(statement) }
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else {
            throw DatabaseError.stepFailed(Self.message(db))
        }
    }

    func query(_ sql: String, values: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        let statement = try prepare(sql, values: values)
        defer { sqlite3_finalize(statement) }

        var rows: [[String: SQLiteValue]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: SQLiteValue] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                guard let name = sqlite3_column_name(statement, index).map({ String(cString: $0) }) else { continue }
                row[name] = Self.columnValue(statement, index: index)
            }
            rows.append(row)
        }
        return rows
    }

    func transaction(_ block: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try block()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func prepare(_ sql: String, values: [SQLiteValue]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(Self.message(db))
        }

        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            guard bind(value, to: statement, index: index) == SQLITE_OK else {
                throw DatabaseError.bindFailed(Self.message(db))
            }
        }
        return statement
    }

    private func bind(_ value: SQLiteValue, to statement: OpaquePointer?, index: Int32) -> Int32 {
        switch value {
        case .null:
            return sqlite3_bind_null(statement, index)
        case .int(let value):
            return sqlite3_bind_int64(statement, index, value)
        case .double(let value):
            return sqlite3_bind_double(statement, index, value)
        case .text(let value):
            return sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        }
    }

    private static func columnValue(_ statement: OpaquePointer?, index: Int32) -> SQLiteValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return .int(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return .double(sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(statement, index) else { return .null }
            return .text(String(cString: text))
        case SQLITE_NULL:
            return .null
        default:
            guard let text = sqlite3_column_text(statement, index) else { return .null }
            return .text(String(cString: text))
        }
    }

    private static func message(_ db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: message)
    }
}

enum SQLiteValue: Hashable {
    case null
    case int(Int64)
    case double(Double)
    case text(String)

    var string: String {
        switch self {
        case .null: ""
        case .int(let value): String(value)
        case .double(let value): String(value)
        case .text(let value): value
        }
    }

    var int: Int {
        switch self {
        case .int(let value): Int(value)
        case .double(let value): Int(value)
        case .text(let value): Int(value) ?? 0
        case .null: 0
        }
    }

    var int64: Int64 {
        switch self {
        case .int(let value): value
        case .double(let value): Int64(value)
        case .text(let value): Int64(value) ?? 0
        case .null: 0
        }
    }

    var double: Double {
        switch self {
        case .double(let value): value
        case .int(let value): Double(value)
        case .text(let value): Double(value) ?? 0
        case .null: 0
        }
    }

    var bool: Bool {
        int != 0
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
