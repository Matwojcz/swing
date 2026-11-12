import Foundation

/// A day marked by hand, such as a medication change or an appointment. Parked (Nov 2026): the app no longer shows,
/// adds or reads markers, but the `marker` table and the rows already made are kept so the idea can come back (see
/// NEXT_ACTIONS.md; the removed views and store are in git history). The MCP server still lists them.
struct DiagramMarker: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case medication, appointment, other
    }

    var id: Int64?
    /// The marked day, `yyyy-MM-dd`, like `MoodEntry.localDate`.
    var localDate: String
    var label: String
    var kind: Kind
}
