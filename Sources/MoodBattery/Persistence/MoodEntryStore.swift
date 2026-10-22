import Foundation
import GRDB

struct MoodEntryStore {
    let dbQueue: DatabaseQueue

    /// Initialises the store with a database queue, defaulting to the shared app database.
    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    /// Inserts or updates a mood entry and returns it with its assigned ID.
    @discardableResult
    func save(_ entry: MoodEntry) throws -> MoodEntry {
        var entry = entry
        try dbQueue.write { db in
            try entry.save(db)
        }
        return entry
    }

    /// Returns all mood entries ordered by timestamp descending (newest first).
    func fetchAll() throws -> [MoodEntry] {
        try dbQueue.write { db in
            try Self.backfillLocalDates(db)
            return try MoodEntry.order(Column("timestamp").desc).fetchAll(db)
        }
    }

    /// Fills in `localDate` for rows that lack it (legacy rows, or rows inserted straight into SQLite),
    /// using the day of their timestamp in the current time zone.
    static func backfillLocalDates(_ db: Database) throws {
        let missing = try MoodEntry.filter(Column("localDate") == "").fetchAll(db)
        for var entry in missing {
            entry.localDate = MoodEntry.localDateString(for: entry.timestamp)
            try entry.update(db)
        }
    }

    /// SQL function `swing_contains(text, term)` used by `search`: case and accent-insensitive substring test,
    /// false for NULL. SQLite's own LIKE only folds ASCII case, which would miss letters like "Ł" or "é".
    /// Register it on any queue that `search` runs on (`DatabaseManager` does this for the app database).
    static let containsFunction = DatabaseFunction("swing_contains", argumentCount: 2, pure: true) { args in
        guard let text = String.fromDatabaseValue(args[0]),
              let term = String.fromDatabaseValue(args[1]) else { return false }
        return EntrySearch.contains(text, term: term)
    }

    /// Scans the database for entries whose title or note contains every word of `query`
    /// (each word may be in either field), newest first. An empty query returns nothing.
    func search(_ query: String) throws -> [MoodEntry] {
        let terms = EntrySearch.words(in: query)
        guard !terms.isEmpty else { return [] }
        let clause = terms
            .map { _ in "(swing_contains(title, ?) OR swing_contains(note, ?))" }
            .joined(separator: " AND ")
        let values: [(any DatabaseValueConvertible)?] = terms.flatMap { [$0, $0] }
        let arguments = StatementArguments(values)
        return try dbQueue.read { db in
            try MoodEntry.fetchAll(
                db,
                sql: "SELECT * FROM moodEntry WHERE \(clause) ORDER BY timestamp DESC",
                arguments: arguments
            )
        }
    }

    /// Deletes every mood entry in the database.
    func deleteAll() throws {
        try dbQueue.write { db in
            _ = try MoodEntry.deleteAll(db)
        }
    }

    /// Checks whether an entry already exists for the given calendar day (matched on the stored `localDate`, not on UTC timestamps).
    func hasEntry(on date: Date) throws -> Bool {
        let day = MoodEntry.localDateString(for: date)
        return try dbQueue.write { db in
            try Self.backfillLocalDates(db)
            return try MoodEntry.filter(Column("localDate") == day).fetchCount(db) > 0
        }
    }

    /// Deletes a single mood entry from the database.
    func delete(_ entry: MoodEntry) throws {
        try dbQueue.write { db in
            _ = try entry.delete(db)
        }
    }
}
