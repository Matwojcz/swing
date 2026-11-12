import Foundation
import GRDB

/// GRDB persistence conformance for DiagramMarker, kept out of the model file like MoodEntry's.
extension DiagramMarker: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "marker"

    /// Captures the auto-incremented row ID after a successful insert.
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
