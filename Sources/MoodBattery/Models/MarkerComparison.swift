import Foundation

/// The logged days before and after a marker, side by side. Descriptive only: it shows what changed around the date,
/// never why, and makes no claim that the marked event caused it.
struct MarkerComparison: Equatable {
    struct Window: Equatable {
        /// Days the window covers so far: fewer than `windowDays` when the marker is recent.
        let days: Int
        let loggedDays: Int
        /// Average of the logged days' moods, nil when none were logged.
        let averageMood: Double?
        /// Logged days at or above the elevated episode threshold (6.5).
        let elevatedDays: Int
        /// Logged days below the depressive episode threshold (3.5).
        let lowDays: Int
    }

    static let windowDays = 30

    /// The `windowDays` days before the marked day.
    let before: Window
    /// The marked day and the days after it, up to `windowDays` and never past `today`.
    let after: Window

    static func compare(entries: [MoodEntry], around day: Date, today: Date = Date(),
                        calendar: Calendar = .current) -> MarkerComparison {
        let marked = calendar.startOfDay(for: day)
        let lastDay = calendar.startOfDay(for: today)
        let byDay = Dictionary(grouping: entries) { $0.day(in: calendar) }
            .mapValues { group in group.reduce(0) { $0 + $1.mood } / Double(group.count) }

        func window(from first: Int, count: Int) -> Window {
            let days = (0..<max(count, 0)).compactMap { calendar.date(byAdding: .day, value: first + $0, to: marked) }
                .filter { $0 <= lastDay }
            let moods = days.compactMap { byDay[$0] }
            return Window(
                days: days.count,
                loggedDays: moods.count,
                averageMood: moods.isEmpty ? nil : moods.reduce(0, +) / Double(moods.count),
                elevatedDays: moods.filter { $0 >= MoodScale.episodeElevatedThreshold }.count,
                lowDays: moods.filter { $0 < MoodScale.episodeDepressiveThreshold }.count
            )
        }

        return MarkerComparison(before: window(from: -windowDays, count: windowDays),
                                after: window(from: 0, count: windowDays))
    }
}
