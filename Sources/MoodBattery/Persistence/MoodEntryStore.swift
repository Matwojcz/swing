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
        try dbQueue.read { db in
            try MoodEntry.order(Column("timestamp").desc).fetchAll(db)
        }
    }

    /// Deletes every mood entry in the database.
    func deleteAll() throws {
        try dbQueue.write { db in
            _ = try MoodEntry.deleteAll(db)
        }
    }

    /// Checks whether an entry already exists for the given calendar day.
    func hasEntry(on date: Date) throws -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return try dbQueue.read { db in
            try MoodEntry
                .filter(Column("timestamp") >= start && Column("timestamp") < end)
                .fetchCount(db) > 0
        }
    }

    /// Deletes a single mood entry from the database.
    func delete(_ entry: MoodEntry) throws {
        try dbQueue.write { db in
            _ = try entry.delete(db)
        }
    }
}
