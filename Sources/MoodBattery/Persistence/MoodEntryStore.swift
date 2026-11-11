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

    /// Writes only the columns that differ between `old` (the entry as the app last read it) and `entry`, so a
    /// column changed outside the app in the meantime (the MCP server) isn't overwritten with a stale value.
    /// Throws if the entry no longer exists, rather than inserting it again.
    func update(_ entry: MoodEntry, from old: MoodEntry) throws {
        try dbQueue.write { db in
            _ = try entry.updateChanges(db, from: old)
        }
    }

    /// Returns one entry, or nil if it doesn't exist (any more).
    func fetch(id: Int64) throws -> MoodEntry? {
        try dbQueue.read { db in
            try MoodEntry.fetchOne(db, key: id)
        }
    }

    /// Writes only the tag columns of one entry, so a title or note edit made while the model was running
    /// isn't overwritten. `title` and `note` are the text the tags were made from: if the entry has changed since,
    /// the tags are kept but left without a version, marking them out of date. With `keepingManual`, hand-picked
    /// tags (set while the model was running) are left as they are. Returns the fresh row, or nil if the entry
    /// was deleted in the meantime.
    func setTags(_ tags: [MoodTag], version: String, forEntryID id: Int64, title: String?, note: String?,
                 keepingManual: Bool) throws -> MoodEntry? {
        try dbQueue.write { db in
            guard var entry = try MoodEntry.fetchOne(db, key: id) else { return nil }
            if keepingManual, entry.hasManualTags { return entry }
            entry.tags = tags.map(\.rawValue)
            entry.tagModelVersion = entry.title == title && entry.note == note ? version : nil
            try entry.update(db, columns: ["tags", "tagModelVersion"])
            return entry
        }
    }

    /// Returns all mood entries ordered by timestamp descending (newest first).
    func fetchAll() throws -> [MoodEntry] {
        try dbQueue.write { db in
            try Self.backfillLocalDates(db)
            return try MoodEntry.order(Column("timestamp").desc).fetchAll(db)
        }
    }

    /// The fallback when `fetchAll` fails: reads the entries one by one and leaves out any that can't be read
    /// (say, a timestamp written from outside in a format the app doesn't know), so one bad row can't hide the diary.
    func fetchReadable() throws -> (entries: [MoodEntry], unreadable: Int) {
        try dbQueue.read { db in
            let ids = try Int64.fetchAll(db, sql: "SELECT id FROM moodEntry ORDER BY timestamp DESC")
            let entries = ids.compactMap { try? MoodEntry.fetchOne(db, key: $0) }
            return (entries, ids.count - entries.count)
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
