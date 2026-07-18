import Foundation
import GRDB

struct MoodEntry: Identifiable, Codable, Equatable {
    var id: Int64?
    /// 0...100, baseline (neutral) at 50.
    var energy: Double
    /// 0...1, blends happy-hype (0) toward irritable-hype (1) above baseline.
    var flavour: Double
    var note: String?
    var timestamp: Date
}

extension MoodEntry: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "moodEntry"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
