import Foundation
import GRDB

final class DatabaseManager {
    static let shared = try! DatabaseManager()

    let dbQueue: DatabaseQueue
    /// Where the daily backups go: `Backups` next to the app's own database, nil for a database at a given path.
    let backupDirectory: URL?
    /// The copy off this Mac, made on every launch: `iCloud Drive/Swing/database-backups`. Nil for a database at a
    /// given path. Only used while the folder exists, so switching iCloud Drive off just stops these copies.
    let iCloudBackupDirectory: URL?

    /// Daily backups kept; older ones are deleted.
    static let backupsToKeep = 14
    /// Launch copies kept in iCloud Drive; older ones are deleted.
    static let iCloudBackupsToKeep = 30

    /// Opens (or creates) the SQLite database at the given path, defaulting to the app's Application Support directory,
    /// backs up the app's own database once a day, and runs pending migrations (after the backup, so a migration that
    /// goes wrong has a copy from before it).
    init(path: String? = nil) throws {
        let dbPath: String
        if let path {
            dbPath = path
            backupDirectory = nil
            iCloudBackupDirectory = nil
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
            backupDirectory = directoryURL.appendingPathComponent("Backups", isDirectory: true)
            iCloudBackupDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Swing/database-backups", isDirectory: true)
        }

        dbQueue = try DatabaseQueue(path: dbPath)
        backUpIfDue()
        backUpToICloud()
        try Self.migrator.migrate(dbQueue)
    }

    /// Copies the database into `iCloudBackupDirectory` as `moodbattery-yyyy-MM-dd-HHmmss.sqlite`, then keeps only
    /// the newest `iCloudBackupsToKeep`. Called once per launch. The copy is written next to the database first and
    /// moved in when complete, so iCloud never uploads a half-written file. Never stops the app: a failure is
    /// reported in the console.
    func backUpToICloud(now: Date = Date()) {
        guard let iCloudBackupDirectory, let backupDirectory else { return }
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: iCloudBackupDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            print("[DatabaseManager] No iCloud backup: \(iCloudBackupDirectory.path) doesn't exist")
            return
        }
        do {
            let stamp = Self.launchStampFormatter.string(from: now)
            let target = iCloudBackupDirectory.appendingPathComponent("moodbattery-\(stamp).sqlite")
            guard !fileManager.fileExists(atPath: target.path) else { return }

            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let partial = backupDirectory.appendingPathComponent("in-progress-icloud.sqlite")
            try? fileManager.removeItem(at: partial)
            let destination = try DatabaseQueue(path: partial.path)
            try dbQueue.backup(to: destination)
            try destination.close()
            try fileManager.moveItem(at: partial, to: target)

            Self.prune(iCloudBackupDirectory, keeping: Self.iCloudBackupsToKeep)
        } catch {
            print("[DatabaseManager] iCloud backup failed: \(error)")
        }
    }

    /// Deletes all but the newest `count` backups (`moodbattery-….sqlite`) in `directory`; other files are left alone.
    private static func prune(_ directory: URL, keeping count: Int) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        let backups = files
            .filter { $0.lastPathComponent.hasPrefix("moodbattery-") && $0.pathExtension == "sqlite" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in backups.dropFirst(count) {
            try? fileManager.removeItem(at: old)
        }
    }

    /// Sorts the same as the date it names, so pruning by name keeps the newest.
    private static let launchStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    /// Copies the database to `Backups/moodbattery-yyyy-MM-dd.sqlite` unless today's copy exists, then keeps only the
    /// newest `backupsToKeep`. Export leaves out period days and markers and can't be read back in, so these copies are
    /// the way back from a bad edit, a sync problem or a migration. Cheap when today's copy exists, so call it freely.
    /// A failed backup never stops the app: it's reported in the console and tried again next time.
    func backUpIfDue(today: Date = Date()) {
        guard let backupDirectory else { return }
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let target = backupDirectory.appendingPathComponent("moodbattery-\(MoodEntry.localDateString(for: today)).sqlite")
            guard !fileManager.fileExists(atPath: target.path) else { return }

            // Written under another name and moved into place, so a half-written copy never passes for a backup.
            let partial = backupDirectory.appendingPathComponent("in-progress.sqlite")
            try? fileManager.removeItem(at: partial)
            let destination = try DatabaseQueue(path: partial.path)
            try dbQueue.backup(to: destination)
            try destination.close()
            try fileManager.moveItem(at: partial, to: target)
            Self.prune(backupDirectory, keeping: Self.backupsToKeep)
        } catch {
            print("[DatabaseManager] Backup failed: \(error)")
        }
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

        migrator.registerMigration("renameEnergyToMood") { db in
            try db.rename(table: "moodEntry", to: "moodEntry_old")
            try db.create(table: "moodEntry") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("mood", .double).notNull()
                t.column("flavour", .double).notNull()
                t.column("note", .text)
                t.column("timestamp", .datetime).notNull()
                t.column("title", .text)
            }
            try db.execute(sql: """
                INSERT INTO moodEntry (id, mood, flavour, note, timestamp, title)
                SELECT id, energy, flavour, note, timestamp, title FROM moodEntry_old
            """)
            try db.drop(table: "moodEntry_old")
        }

        migrator.registerMigration("scaleMood0to10") { db in
            try db.execute(sql: "UPDATE moodEntry SET mood = mood / 10.0")
        }

        migrator.registerMigration("addLocalDate") { db in
            try db.alter(table: "moodEntry") { t in
                t.add(column: "localDate", .text).notNull().defaults(to: "")
            }
            try MoodEntryStore.backfillLocalDates(db)
        }

        migrator.registerMigration("addTags") { db in
            try db.alter(table: "moodEntry") { t in
                t.add(column: "tags", .text).notNull().defaults(to: "[]")
                t.add(column: "tagModelVersion", .text)
            }
        }

        migrator.registerMigration("createPeriodStart") { db in
            try db.create(table: "periodStart") { t in
                t.primaryKey("localDate", .text)
            }
        }

        migrator.registerMigration("createMarker") { db in
            try db.create(table: "marker") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("localDate", .text).notNull().indexed()
                t.column("label", .text).notNull()
                t.column("kind", .text).notNull()
            }
        }

        return migrator
    }
}
