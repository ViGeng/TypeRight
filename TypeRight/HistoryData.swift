//
//  HistoryData.swift
//  TypeRight
//
//  Created by Claude on 03.02.26.
//

import Foundation
import SQLite3

/// Represents hourly keystroke statistics
struct HourlyStats: Identifiable {
    let id: Int64
    let hour: Date           // Rounded to hour
    let keystrokes: Int
    let backspaces: Int
    
    var ratio: Double {
        guard keystrokes > 0 else { return 0 }
        return (Double(backspaces) / Double(keystrokes)) * 100
    }
}

/// Manages SQLite storage for historical keystroke data
class HistoryDataManager {
    static let shared = HistoryDataManager()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        // Store in Application Support directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TypeRight", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        dbPath = appFolder.appendingPathComponent("history.sqlite").path
        openDatabase()
        createTableIfNeeded()
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    private func createTableIfNeeded() {
        let createSQL = """
            CREATE TABLE IF NOT EXISTS hourly_stats (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hour_timestamp INTEGER NOT NULL UNIQUE,
                keystrokes INTEGER NOT NULL,
                backspaces INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_hour ON hourly_stats(hour_timestamp);
        """
        
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createSQL, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("Error creating table: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }
    
    /// Round a date to the start of its hour
    func startOfHour(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Record keystrokes for a specific hour (upsert)
    func recordHour(hour: Date, keystrokes: Int, backspaces: Int) {
        let hourTimestamp = Int64(startOfHour(for: hour).timeIntervalSince1970)
        
        let upsertSQL = """
            INSERT INTO hourly_stats (hour_timestamp, keystrokes, backspaces)
            VALUES (?, ?, ?)
            ON CONFLICT(hour_timestamp) DO UPDATE SET
                keystrokes = keystrokes + excluded.keystrokes,
                backspaces = backspaces + excluded.backspaces;
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, upsertSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, hourTimestamp)
            sqlite3_bind_int(stmt, 2, Int32(keystrokes))
            sqlite3_bind_int(stmt, 3, Int32(backspaces))
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("Error inserting data: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(stmt)
    }
    
    /// Get stats for the last N hours
    func getStats(lastHours hours: Int) -> [HourlyStats] {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        return getStats(since: cutoff)
    }
    
    /// Get stats since a specific date
    func getStats(since date: Date) -> [HourlyStats] {
        var results: [HourlyStats] = []
        let timestamp = Int64(date.timeIntervalSince1970)
        
        let querySQL = """
            SELECT id, hour_timestamp, keystrokes, backspaces
            FROM hourly_stats
            WHERE hour_timestamp >= ?
            ORDER BY hour_timestamp ASC;
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, timestamp)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let hourTimestamp = sqlite3_column_int64(stmt, 1)
                let keystrokes = Int(sqlite3_column_int(stmt, 2))
                let backspaces = Int(sqlite3_column_int(stmt, 3))
                
                let hour = Date(timeIntervalSince1970: Double(hourTimestamp))
                let stat = HourlyStats(id: id, hour: hour, keystrokes: keystrokes, backspaces: backspaces)
                results.append(stat)
            }
        }
        sqlite3_finalize(stmt)
        
        return results
    }
    
    /// Get all-time stats
    func getAllTimeStats() -> (keystrokes: Int, backspaces: Int) {
        var totalKeystrokes = 0
        var totalBackspaces = 0
        
        let querySQL = "SELECT SUM(keystrokes), SUM(backspaces) FROM hourly_stats;"
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalKeystrokes = Int(sqlite3_column_int64(stmt, 0))
                totalBackspaces = Int(sqlite3_column_int64(stmt, 1))
            }
        }
        sqlite3_finalize(stmt)
        
        return (totalKeystrokes, totalBackspaces)
    }
    
    /// Reset all historical data
    func resetAll() {
        let deleteSQL = "DELETE FROM hourly_stats;"
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, deleteSQL, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("Error deleting data: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
}
