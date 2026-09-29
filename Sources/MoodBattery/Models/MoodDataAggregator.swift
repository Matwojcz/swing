import Foundation

/// Aggregates raw mood entries into per-day or per-week averages for plotting.
///
/// Pure domain logic — no dependencies on views or the persistence layer. Both aggregation
/// functions accept the calendar to use, so tests can pin a deterministic time zone.
enum MoodDataAggregator {
    /// One aggregated data point ready for plotting: a mood/flavour pair anchored at a day index and calendar date.
    struct DataPoint {
        var dayIndex: Int
        var mood: Double
        var flavour: Double
        var date: Date
    }

    /// Computes one averaged data point per day in `days`, skipping days with no entries.
    /// The returned `dayIndex` matches the position in the `days` array.
    static func dailyAverages(entries: [MoodEntry], days: [Date], calendar: Calendar = .current) -> [DataPoint] {
        let grouped = groupByDay(entries: entries, calendar: calendar)
        return days.enumerated().compactMap { index, day in
            let key = calendar.startOfDay(for: day)
            guard let dayEntries = grouped[key], !dayEntries.isEmpty else { return nil }
            let count = Double(dayEntries.count)
            return DataPoint(
                dayIndex: index,
                mood: dayEntries.reduce(0) { $0 + $1.mood } / count,
                flavour: dayEntries.reduce(0) { $0 + $1.flavour } / count,
                date: day
            )
        }
    }

    /// Aggregates entries into fixed 7-day chunks across `days`, placing each averaged point at the chunk's midpoint index. Used by the year-scale diagram.
    static func weeklyAverages(entries: [MoodEntry], days: [Date], calendar: Calendar = .current) -> [DataPoint] {
        let grouped = groupByDay(entries: entries, calendar: calendar)
        var points: [DataPoint] = []
        let chunkSize = 7
        let chunkCount = days.count / chunkSize

        for chunk in 0..<chunkCount {
            let startIdx = chunk * chunkSize
            let midIdx = startIdx + chunkSize / 2
            var moodSum = 0.0
            var flavourSum = 0.0
            var count = 0.0

            for i in startIdx..<(startIdx + chunkSize) {
                let key = calendar.startOfDay(for: days[i])
                if let dayEntries = grouped[key] {
                    for e in dayEntries {
                        moodSum += e.mood
                        flavourSum += e.flavour
                        count += 1
                    }
                }
            }

            if count > 0 {
                points.append(DataPoint(
                    dayIndex: midIdx,
                    mood: moodSum / count,
                    flavour: flavourSum / count,
                    date: days[midIdx]
                ))
            }
        }
        return points
    }

    /// Groups entries by their calendar day (start-of-day date), used by both aggregators for O(1) day lookups.
    private static func groupByDay(entries: [MoodEntry], calendar: Calendar) -> [Date: [MoodEntry]] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
    }
}
