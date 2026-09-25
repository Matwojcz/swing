import Foundation
import GRDB

final class DatabaseManager {
    static let shared = try! DatabaseManager()

    let dbQueue: DatabaseQueue

    init(path: String? = nil) throws {
        let dbPath: String
        if let path {
            dbPath = path
        } else {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directoryURL = appSupportURL.appendingPathComponent("MoodBattery", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            dbPath = directoryURL.appendingPathComponent("moodbattery.sqlite").path
        }

        dbQueue = try DatabaseQueue(path: dbPath)
        try Self.migrator.migrate(dbQueue)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createMoodEntry") { db in
            try db.create(table: "moodEntry") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("energy", .double).notNull()
                t.column("flavour", .double).notNull()
                t.column("note", .text)
                t.column("timestamp", .datetime).notNull()
            }
        }

        migrator.registerMigration("addTitle") { db in
            try db.alter(table: "moodEntry") { t in
                t.add(column: "title", .text)
            }
        }

        return migrator
    }
}
