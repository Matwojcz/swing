import Foundation

/// Detects sustained mood-episode periods (depressive or elevated) across a set of entries.
///
/// Uses a sliding 5-day window: if 4+ days in the window cross the threshold in one direction,
/// the span is flagged as an episode. Consecutive matching windows extend the same episode.
/// Nearby episodes of the same type (gap ≤ 3 days) are merged, with averages recomputed.
///
/// Pure domain logic — no dependencies on views. Callers supply the calendar so tests can pin
/// a deterministic time zone.
enum EpisodeDetector {
    /// The kind of mood episode detected.
    enum EpisodeType {
        case depressive, elevated
    }

    /// A contiguous span of days flagged as a single mood episode, with the average mood and flavour across the span.
    struct Episode {
        var startDate: Date
        var endDate: Date
        var type: EpisodeType
        var averageMood: Double
        var averageFlavour: Double
    }

    /// A single day's averaged mood and flavour, or nil if no entries fell on that day.
    private struct DayMood {
        var mood: Double
        var flavour: Double
    }

    /// Runs global episode detection across all entries and returns merged episodes of both types.
    static func detect(entries: [MoodEntry], calendar: Calendar = .current) -> [Episode] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
        let sortedDates = entries.map { calendar.startOfDay(for: $0.timestamp) }
        guard let earliest = sortedDates.min(), let latest = sortedDates.max() else { return [] }

        let totalDays = (calendar.dateComponents([.day], from: earliest, to: latest).day ?? 0) + 1
        guard totalDays >= 5 else { return [] }

        let allDays = (0..<totalDays).map { calendar.date(byAdding: .day, value: $0, to: earliest)! }

        let dayMoods: [DayMood?] = allDays.map { day in
            let key = calendar.startOfDay(for: day)
            guard let dayEntries = grouped[key], !dayEntries.isEmpty else { return nil }
            let count = Double(dayEntries.count)
            return DayMood(
                mood: dayEntries.reduce(0) { $0 + $1.mood } / count,
                flavour: dayEntries.reduce(0) { $0 + $1.flavour } / count
            )
        }

        var episodes: [Episode] = []
        episodes.append(contentsOf: scan(
            dayMoods: dayMoods, allDays: allDays,
            threshold: MoodScale.episodeDepressiveThreshold, below: true
        ))
        episodes.append(contentsOf: scan(
            dayMoods: dayMoods, allDays: allDays,
            threshold: MoodScale.episodeElevatedThreshold, below: false
        ))

        return merge(episodes: episodes, calendar: calendar)
    }

    /// Sliding-window scan over day-mood series: flags spans where 4 of 5 days cross the threshold.
    private static func scan(dayMoods: [DayMood?], allDays: [Date], threshold: Double, below: Bool) -> [Episode] {
        var result: [Episode] = []
        let windowSize = 5
        guard dayMoods.count >= windowSize else { return result }

        var inEpisode = false
        var episodeStart = 0
        var lastEnd = 0

        for i in 0...(dayMoods.count - windowSize) {
            var qualifying = 0
            for j in i..<(i + windowSize) {
                guard let m = dayMoods[j] else { continue }
                if below ? m.mood < threshold : m.mood > threshold {
                    qualifying += 1
                }
            }

            if qualifying >= 4 {
                if !inEpisode {
                    inEpisode = true
                    episodeStart = i
                }
                lastEnd = i + windowSize - 1
            } else if inEpisode {
                result.append(makeEpisode(
                    dayMoods: dayMoods, allDays: allDays,
                    start: episodeStart, end: min(lastEnd, dayMoods.count - 1),
                    threshold: threshold, below: below
                ))
                inEpisode = false
            }
        }

        if inEpisode {
            result.append(makeEpisode(
                dayMoods: dayMoods, allDays: allDays,
                start: episodeStart, end: min(lastEnd, dayMoods.count - 1),
                threshold: threshold, below: below
            ))
        }

        return result
    }

    /// Builds an Episode from the day range, computing average mood/flavour across the qualifying days.
    private static func makeEpisode(dayMoods: [DayMood?], allDays: [Date], start: Int, end: Int, threshold: Double, below: Bool) -> Episode {
        var moodAcc = 0.0, flavourAcc = 0.0, cnt = 0
        for j in start...end {
            if let m = dayMoods[j] { moodAcc += m.mood; flavourAcc += m.flavour; cnt += 1 }
        }
        return Episode(
            startDate: allDays[start],
            endDate: allDays[end],
            type: below ? .depressive : .elevated,
            averageMood: cnt > 0 ? moodAcc / Double(cnt) : threshold,
            averageFlavour: cnt > 0 ? flavourAcc / Double(cnt) : 0.5
        )
    }

    /// Merges episodes of the same type separated by ≤ 3 days into single episodes, recomputing averages.
    private static func merge(episodes: [Episode], calendar: Calendar) -> [Episode] {
        var merged: [Episode] = []
        let sorted = episodes.sorted { $0.startDate < $1.startDate }
        for ep in sorted {
            if let last = merged.last,
               last.type == ep.type,
               let gap = calendar.dateComponents([.day], from: last.endDate, to: ep.startDate).day,
               gap <= 3 {
                var combined = merged.removeLast()
                combined.endDate = ep.endDate
                let totalCount = 2.0
                combined.averageMood = (last.averageMood + ep.averageMood) / totalCount
                combined.averageFlavour = (last.averageFlavour + ep.averageFlavour) / totalCount
                merged.append(combined)
            } else {
                merged.append(ep)
            }
        }
        return merged
    }
}
