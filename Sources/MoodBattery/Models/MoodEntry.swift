import Foundation

/// A single mood log — the domain model, with no dependency on the persistence library.
/// GRDB conformance lives in `Persistence/MoodEntry+GRDB.swift`.
struct MoodEntry: Identifiable, Codable, Equatable {
    var id: Int64?
    /// 0...10 in 0.5 steps, baseline (neutral) at 5.
    var mood: Double
    /// 0...1, blends happy-hype (0) toward irritable-hype (1) above baseline.
    var flavour: Double
    var title: String?
    var note: String?
    var timestamp: Date
}
