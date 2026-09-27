import Foundation
import GRDB

struct MoodEntryStore {
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func save(_ entry: MoodEntry) throws -> MoodEntry {
        var entry = entry
        try dbQueue.write { db in
            try entry.save(db)
        }
        return entry
    }

    func fetchAll() throws -> [MoodEntry] {
        try dbQueue.read { db in
            try MoodEntry.order(Column("timestamp").desc).fetchAll(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            _ = try MoodEntry.deleteAll(db)
        }
    }

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

    func delete(_ entry: MoodEntry) throws {
        try dbQueue.write { db in
            _ = try entry.delete(db)
        }
    }
}
