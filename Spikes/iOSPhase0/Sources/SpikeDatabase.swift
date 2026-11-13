import Foundation
import GRDB

/// Checks 1–2: GRDB opens a database on the phone, and its contents survive relaunches and SideStore refreshes.
/// Every launch adds a row, so a growing count proves the data was kept.
struct SpikeDatabase {
    let dbQueue: DatabaseQueue

    init() throws {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        dbQueue = try DatabaseQueue(path: directory.appendingPathComponent("spike.sqlite").path)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createLaunch") { db in
            try db.create(table: "launch") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("at", .datetime).notNull()
            }
        }
        try migrator.migrate(dbQueue)
    }

    /// Records this launch and returns how many launches are stored and when the first was.
    func recordLaunch() throws -> (count: Int, first: Date?) {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO launch (at) VALUES (?)", arguments: [Date()])
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM launch") ?? 0
            let first = try Date.fetchOne(db, sql: "SELECT MIN(at) FROM launch")
            return (count, first)
        }
    }
}
