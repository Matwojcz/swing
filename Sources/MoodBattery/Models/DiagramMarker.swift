import Foundation

/// A day marked by hand, such as a medication change or an appointment. Parked (Nov 2026): the app no longer shows or
/// adds markers, but the table and the rows already made are kept so the idea can come back (see NEXT_ACTIONS.md).
/// The MCP server still lists them.
struct DiagramMarker: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case medication, appointment, other

        var id: String { rawValue }

        var name: String {
            switch self {
            case .medication: "Medication"
            case .appointment: "Appointment"
            case .other: "Other"
            }
        }

        /// SF Symbol shown with the marker.
        var symbol: String {
            switch self {
            case .medication: "pills"
            case .appointment: "stethoscope"
            case .other: "flag"
            }
        }
    }

    var id: Int64?
    /// The marked day, `yyyy-MM-dd`, like `MoodEntry.localDate`.
    var localDate: String
    var label: String
    var kind: Kind

    /// The marked day as a start-of-day `Date` in `calendar`.
    func day(in calendar: Calendar = .current) -> Date? {
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return nil }
        return calendar.startOfDay(for: date)
    }
}
