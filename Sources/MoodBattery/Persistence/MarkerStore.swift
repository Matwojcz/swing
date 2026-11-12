import Foundation
import GRDB

/// The markers placed by hand on the diagram. Parked with `DiagramMarker`: nothing in the app uses it for now.
struct MarkerStore {
    let dbQueue: DatabaseQueue

    /// Initialises the store with a database queue, defaulting to the shared app database.
    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    /// Returns every marker, oldest day first.
    func fetchAll() throws -> [DiagramMarker] {
        try dbQueue.read { db in
            try DiagramMarker.order(Column("localDate"), Column("id")).fetchAll(db)
        }
    }

    /// Inserts a new marker or updates an existing one.
    func save(_ marker: DiagramMarker) throws {
        var marker = marker
        try dbQueue.write { db in
            try marker.save(db)
        }
    }

    func delete(_ marker: DiagramMarker) throws {
        try dbQueue.write { db in
            _ = try marker.delete(db)
        }
    }
}
