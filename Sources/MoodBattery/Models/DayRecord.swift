import Foundation

/// Whether a day stands out against the days before it: its lowest or highest mood for at least two weeks.
/// Shown when hovering a dot ("Lowest since 26 Oct"). Descriptive only.
enum DayRecord {
    enum Kind: Equatable {
        case lowest, highest
    }

    struct Result: Equatable {
        let kind: Kind
        /// The last earlier day that was at least as low (or as high); nil when no earlier day was, so the day is the
        /// lowest (or highest) since logging began.
        let since: Date?
    }

    /// A day counts as standing out only when it's the lowest or highest for at least this many days.
    static let minimumDays = 14

    /// The lowest-or-highest-since record for `day`, nil for an ordinary day or a day without an entry. Days with
    /// several entries use their average, as the diagram does. When a day is both (a flat stretch), the longer wins.
    static func find(for day: Date, entries: [MoodEntry], calendar: Calendar = .current) -> Result? {
        let target = calendar.startOfDay(for: day)
        let moods = Dictionary(grouping: entries) { $0.day(in: calendar) }
            .mapValues { group in group.reduce(0) { $0 + $1.mood } / Double(group.count) }
        guard let mood = moods[target], let first = moods.keys.min() else { return nil }
        let earlier = moods.filter { $0.key < target }.sorted { $0.key > $1.key }

        func record(_ kind: Kind, beats: (Double) -> Bool) -> (result: Result, days: Int)? {
            // The nearest earlier day that this one doesn't beat ends the run.
            if let blocker = earlier.first(where: { !beats($0.value) }) {
                let days = calendar.dateComponents([.day], from: blocker.key, to: target).day ?? 0
                return days >= minimumDays ? (Result(kind: kind, since: blocker.key), days) : nil
            }
            let days = calendar.dateComponents([.day], from: first, to: target).day ?? 0
            return days >= minimumDays ? (Result(kind: kind, since: nil), days) : nil
        }

        let lowest = record(.lowest) { mood < $0 }
        let highest = record(.highest) { mood > $0 }
        switch (lowest, highest) {
        case let (low?, high?): return low.days >= high.days ? low.result : high.result
        case let (low?, nil): return low.result
        case let (nil, high?): return high.result
        default: return nil
        }
    }
}
