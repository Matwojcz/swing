import Foundation

/// Serialises mood entries to CSV or JSON. Pure formatting — no file I/O and no UI, so the caller
/// (ContentView, tests, or future automation) picks how the bytes leave the process.
enum ExportService {
    /// Builds a CSV representation with a header row and ISO-8601 timestamps.
    static func csv(from entries: [MoodEntry]) -> String {
        let header = "id,mood,flavour,title,note,timestamp,localDate"
        let rows = entries.map { e in
            let fields: [String] = [
                e.id.map(String.init) ?? "",
                String(e.mood),
                String(e.flavour),
                csvEscape(e.title ?? ""),
                csvEscape(e.note ?? ""),
                iso8601Formatter.string(from: e.timestamp),
                e.localDate
            ]
            return fields.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Encodes entries as pretty-printed JSON with ISO-8601 dates and sorted keys for stable diffs.
    static func json(from entries: [MoodEntry]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Wraps a string in double quotes and escapes inner quotes if it contains CSV-special characters.
    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
