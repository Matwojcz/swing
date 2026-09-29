import Foundation
import GRDB

/// GRDB persistence conformance for MoodEntry — kept out of the model file so the domain
/// type has no dependency on the persistence library.
extension MoodEntry: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "moodEntry"

    /// Captures the auto-incremented row ID after a successful insert.
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
