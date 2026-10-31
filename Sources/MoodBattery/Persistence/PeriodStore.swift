import Foundation
import GRDB

/// The days a period started, logged by hand for the PMDD lens. Each day is a `yyyy-MM-dd` string, like `MoodEntry.localDate`.
struct PeriodStore {
    let dbQueue: DatabaseQueue

    /// Initialises the store with a database queue, defaulting to the shared app database.
    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    /// Returns every logged start day, oldest first.
    func fetchStarts() throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT localDate FROM periodStart ORDER BY localDate")
        }
    }

    /// Marks or unmarks `localDate` as a day a period started.
    func setStart(_ localDate: String, isStart: Bool) throws {
        try dbQueue.write { db in
            if isStart {
                try db.execute(sql: "INSERT OR IGNORE INTO periodStart (localDate) VALUES (?)", arguments: [localDate])
            } else {
                try db.execute(sql: "DELETE FROM periodStart WHERE localDate = ?", arguments: [localDate])
            }
        }
    }
}
