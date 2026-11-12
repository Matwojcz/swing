import Foundation

/// Whether a day stands out against the days before it: its lowest or highest mood for at least two weeks.
/// Shown when hovering a dot ("Lowest since 26 Oct"). Descriptive only.
enum DayRecord {
    enum Kind: Equatable {
        case lowest, highest
    }

    struct Result: Equatable {
        let kind: Kind
        /// The last earlier day that was lower (or higher); nil when none was, so nothing lower (or higher) has been
        /// logged at all.
        let since: Date?
        /// The latest day since then that was exactly as low (or high), if any: the card then reads "As low as <day>".
        let tiedWith: Date?
    }

    /// A day counts as standing out only when nothing lower (or higher) was logged for at least this many days.
    static let minimumDays = 14

    /// The record for `day`, nil for an ordinary day or a day without an entry. Days with several entries use their
    /// average, as the diagram does, compared at one decimal so equal-looking days tie. When a day is both (a flat
    /// stretch), the longer run wins.
    static func find(for day: Date, entries: [MoodEntry], calendar: Calendar = .current) -> Result? {
        let target = calendar.startOfDay(for: day)
        let tenths = Dictionary(grouping: entries) { $0.day(in: calendar) }
            .mapValues { group in Int((group.reduce(0) { $0 + $1.mood } / Double(group.count) * 10).rounded()) }
        guard let mood = tenths[target], let first = tenths.keys.min() else { return nil }
        let earlier = tenths.filter { $0.key < target }.sorted { $0.key > $1.key }

        func record(_ kind: Kind, beyond: (Int) -> Bool) -> (result: Result, days: Int)? {
            // The nearest earlier day further out than this one ends the run; equal days on the way are ties.
            let blocker = earlier.first { beyond($0.value) }
            let start = blocker?.key ?? first
            let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
            guard days >= minimumDays else { return nil }
            let tie = earlier.first { $0.key > start && $0.value == mood }?.key
                ?? (blocker == nil && tenths[first] == mood && first < target ? first : nil)
            return (Result(kind: kind, since: blocker?.key, tiedWith: tie), days)
        }

        let lowest = record(.lowest) { $0 < mood }
        let highest = record(.highest) { $0 > mood }
        switch (lowest, highest) {
        case let (low?, high?): return low.days >= high.days ? low.result : high.result
        case let (low?, nil): return low.result
        case let (nil, high?): return high.result
        default: return nil
        }
    }
}
