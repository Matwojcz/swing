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
    /// The calendar day (`yyyy-MM-dd`) the entry belongs to, fixed at the wall-clock day it was logged.
    /// Unlike `timestamp`, it never shifts when the system time zone or DST changes. Empty only for
    /// rows inserted outside the app, which are backfilled from `timestamp` on first read.
    var localDate: String

    /// Creates an entry; `localDate` defaults to the day of `timestamp` in the current time zone.
    init(id: Int64?, mood: Double, flavour: Double, title: String? = nil, note: String? = nil,
         timestamp: Date, localDate: String? = nil) {
        self.id = id
        self.mood = mood
        self.flavour = flavour
        self.title = title
        self.note = note
        self.timestamp = timestamp
        self.localDate = localDate ?? Self.localDateString(for: timestamp)
    }

    /// Formats the calendar day of `date` in `calendar` as `yyyy-MM-dd`.
    static func localDateString(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 1, c.day ?? 1)
    }

    /// The entry's day as a start-of-day `Date` in `calendar`, taken from `localDate` so the day
    /// stays put when the system time zone changes. Used by every per-day grouping.
    func day(in calendar: Calendar = .current) -> Date {
        let source = localDate.isEmpty ? Self.localDateString(for: timestamp, calendar: calendar) : localDate
        let parts = source.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return calendar.startOfDay(for: timestamp) }
        return calendar.startOfDay(for: date)
    }
}
