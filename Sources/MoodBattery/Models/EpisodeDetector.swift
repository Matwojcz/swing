import Foundation

/// Detects sustained mood-episode periods (depressive or elevated) across a set of entries.
///
/// Modelled on DSM-5 bipolar II: a depressive episode needs at least 14 days, an elevated
/// (hypomanic) one at least 4. A run starts and ends on a day whose average mood crosses the
/// threshold (below 3.5 / above 6.5). Between those days it bridges up to a few consecutive
/// non-qualifying days — unlogged days, or logged days near baseline (up to 5.5 for depressive runs,
/// down to 4.5 for elevated ones) — but a logged day on the opposite side ends it. The span must also
/// be at least 70% logged qualifying days, so sparse logging can't stretch an episode.
///
/// Pure domain logic — no dependencies on views. Callers supply the calendar so tests can pin
/// a deterministic time zone.
enum EpisodeDetector {
    /// The kind of mood episode detected.
    enum EpisodeType {
        case depressive, elevated
    }

    /// A contiguous span of days flagged as a single mood episode, with the average mood and flavour across its logged days.
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

    /// How a day relates to the run being scanned.
    private enum DayKind {
        /// Past the episode threshold.
        case qualifying
        /// Unlogged, or logged near baseline: bridged within the gap limit but not counted.
        case gap
        /// Logged on the opposite side of baseline: ends the run.
        case breaking
    }

    /// Runs global episode detection across all entries and returns the depressive and elevated episodes, ordered by start date.
    static func detect(entries: [MoodEntry], calendar: Calendar = .current) -> [Episode] {
        let grouped = Dictionary(grouping: entries) { $0.day(in: calendar) }
        let sortedDates = entries.map { $0.day(in: calendar) }
        guard let earliest = sortedDates.min(), let latest = sortedDates.max() else { return [] }

        let totalDays = (calendar.dateComponents([.day], from: earliest, to: latest).day ?? 0) + 1
        guard totalDays >= MoodScale.episodeElevatedMinDays else { return [] }

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

        let depressive = scan(
            dayMoods: dayMoods, allDays: allDays, below: true,
            threshold: MoodScale.episodeDepressiveThreshold,
            toleratedLimit: MoodScale.episodeDepressiveToleratedMax,
            minDays: MoodScale.episodeDepressiveMinDays,
            maxGap: MoodScale.episodeDepressiveMaxGapDays
        )
        let elevated = scan(
            dayMoods: dayMoods, allDays: allDays, below: false,
            threshold: MoodScale.episodeElevatedThreshold,
            toleratedLimit: MoodScale.episodeElevatedToleratedMin,
            minDays: MoodScale.episodeElevatedMinDays,
            maxGap: MoodScale.episodeElevatedMaxGapDays
        )
        return (depressive + elevated).sorted { $0.startDate < $1.startDate }
    }

    /// Classifies one day for a scan: qualifying past `threshold`, breaking beyond `toleratedLimit` on the opposite side, otherwise a gap.
    private static func kind(of day: DayMood?, below: Bool, threshold: Double, toleratedLimit: Double) -> DayKind {
        guard let day else { return .gap }
        if below {
            if day.mood < threshold { return .qualifying }
            return day.mood > toleratedLimit ? .breaking : .gap
        }
        if day.mood > threshold { return .qualifying }
        return day.mood < toleratedLimit ? .breaking : .gap
    }

    /// Scans for runs that start on a qualifying day, bridge at most `maxGap` consecutive gap days, stop at a breaking day, and are trimmed to their last qualifying day.
    /// A run becomes an episode if it spans at least `minDays` and at least 70% of the span is qualifying days; otherwise scanning resumes from the next day.
    private static func scan(dayMoods: [DayMood?], allDays: [Date], below: Bool, threshold: Double,
                             toleratedLimit: Double, minDays: Int, maxGap: Int) -> [Episode] {
        let kinds = dayMoods.map { kind(of: $0, below: below, threshold: threshold, toleratedLimit: toleratedLimit) }
        var result: [Episode] = []
        var start = 0

        while start < kinds.count {
            guard kinds[start] == .qualifying else { start += 1; continue }

            var lastQualifying = start
            var qualifying = 1
            var gapRun = 0
            var j = start + 1
            while j < kinds.count {
                if kinds[j] == .qualifying {
                    lastQualifying = j
                    qualifying += 1
                    gapRun = 0
                } else if kinds[j] == .gap {
                    gapRun += 1
                    if gapRun > maxGap { break }
                } else {
                    break
                }
                j += 1
            }

            let span = lastQualifying - start + 1
            if span >= minDays && Double(qualifying) >= MoodScale.episodeMinQualifyingShare * Double(span) {
                result.append(makeEpisode(
                    dayMoods: dayMoods, allDays: allDays,
                    start: start, end: lastQualifying,
                    threshold: threshold, below: below
                ))
                start = lastQualifying + 1
            } else {
                start += 1
            }
        }
        return result
    }

    /// Builds an Episode from the day range, computing average mood/flavour across the logged days.
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
}
