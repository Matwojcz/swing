import Foundation

/// Where a day sits in the menstrual cycle, worked out from the logged period start days. Used by the PMDD lens.
///
/// PMDD symptoms cluster in the week before a period and ease within a few days of it starting, so the
/// premenstrual window is counted back from the next start: the logged one when there is one, otherwise
/// a prediction from the typical cycle length (the second half of the cycle varies far less than the first).
struct CycleCalendar: Equatable {
    enum Phase: String {
        case period, follicular, luteal, premenstrual
    }

    struct Position: Equatable {
        /// 1 on the day a period starts.
        let day: Int
        let phase: Phase
    }

    /// Logged start days as start-of-day dates, oldest first.
    let starts: [Date]

    static let empty = CycleCalendar(starts: [])

    /// Days counted as the period itself.
    static let periodDays = 5
    /// The premenstrual window: this many days before the next start.
    static let premenstrualDays = 7
    /// Ovulation falls roughly this many days before the next start; the luteal phase runs from there.
    static let lutealDays = 14
    /// Used until two starts give a real cycle length.
    static let defaultLength = 28
    /// Gaps outside this range are treated as missed logs, not cycles.
    static let plausibleLengths = 21...45

    private let calendar: Calendar

    init(starts: [Date], calendar: Calendar = .current) {
        self.calendar = calendar
        self.starts = starts.map { calendar.startOfDay(for: $0) }.sorted()
    }

    /// Builds the calendar from `yyyy-MM-dd` day strings.
    init(localDates: [String], calendar: Calendar = .current) {
        let dates = localDates.compactMap { string -> Date? in
            let parts = string.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }
        self.init(starts: dates, calendar: calendar)
    }

    static func == (lhs: CycleCalendar, rhs: CycleCalendar) -> Bool { lhs.starts == rhs.starts }

    func isStart(_ date: Date) -> Bool {
        starts.contains(calendar.startOfDay(for: date))
    }

    /// The median gap between consecutive starts, ignoring implausible gaps; the default without any.
    var typicalLength: Int {
        let gaps = zip(starts, starts.dropFirst())
            .map { days(from: $0, to: $1) }
            .filter { Self.plausibleLengths.contains($0) }
            .sorted()
        return gaps.isEmpty ? Self.defaultLength : gaps[gaps.count / 2]
    }

    /// The day's place in its cycle, or nil before the first logged start or when the last start is too long ago
    /// to say (a period probably went unlogged).
    func position(of date: Date) -> Position? {
        let day = calendar.startOfDay(for: date)
        guard let start = starts.last(where: { $0 <= day }) else { return nil }
        let cycleDay = days(from: start, to: day) + 1
        guard cycleDay <= Self.plausibleLengths.upperBound else { return nil }

        let daysToNext: Int
        if let next = starts.first(where: { $0 > day }) {
            daysToNext = days(from: day, to: next)
        } else {
            daysToNext = typicalLength - cycleDay + 1
        }

        let phase: Phase
        if cycleDay <= Self.periodDays {
            phase = .period
        } else if daysToNext <= Self.premenstrualDays {
            phase = .premenstrual
        } else if daysToNext <= Self.lutealDays {
            phase = .luteal
        } else {
            phase = .follicular
        }
        return Position(day: cycleDay, phase: phase)
    }

    private func days(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
