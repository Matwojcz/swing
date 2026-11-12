import Foundation

/// Reads the CSV and JSON files that `ExportService` writes, so an export can be brought back in (or into another
/// copy of Swing). Pure parsing: no UI, no database. Rows that can't be read are counted, not guessed at.
enum ExportFileImporter {
    enum ImportError: LocalizedError {
        case missingColumns([String])
        case notAnExport

        var errorDescription: String? {
            switch self {
            case .missingColumns(let names):
                "This CSV doesn't look like a Swing export: it has no \(names.joined(separator: " or ")) column."
            case .notAnExport:
                "This JSON doesn't look like a Swing export: it should be a list of entries."
            }
        }
    }

    /// Entries read from a file, and how many rows were left out because a value was missing or out of range.
    struct Result {
        var entries: [MoodEntry]
        var skipped: Int
    }

    // MARK: - CSV

    /// Reads an export CSV (`id,mood,flavour,title,note,timestamp,localDate,tags,tagModelVersion`). Columns are found by
    /// name, so their order doesn't matter and older exports without the last columns still read; `id` is ignored,
    /// since the entries get new ones. Tags are `;`-separated.
    static func entries(fromCSV text: String) throws -> Result {
        let rows = csvRows(text)
        guard let header = rows.first?.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) else {
            return Result(entries: [], skipped: 0)
        }
        func column(_ name: String) -> Int? { header.firstIndex(of: name) }
        let missing = ["mood", "flavour", "timestamp"].filter { column($0) == nil }
        guard missing.isEmpty else { throw ImportError.missingColumns(missing) }

        var result = Result(entries: [], skipped: 0)
        for row in rows.dropFirst() where !(row.count == 1 && row[0].isEmpty) {
            func value(_ name: String) -> String? {
                guard let index = column(name), index < row.count else { return nil }
                return row[index]
            }
            let tags = (value("tags") ?? "").split(separator: ";").map(String.init).filter { !$0.isEmpty }
            let version = value("tagmodelversion").flatMap { $0.isEmpty ? nil : $0 }
            if let entry = makeEntry(mood: value("mood").flatMap(Double.init), flavour: value("flavour").flatMap(Double.init),
                                     title: value("title"), note: value("note"),
                                     timestamp: value("timestamp").flatMap(parseDate),
                                     localDate: value("localdate"), tags: tags, tagModelVersion: version) {
                result.entries.append(entry)
            } else {
                result.skipped += 1
            }
        }
        return result
    }

    /// Splits CSV text into rows of fields: quoted fields may hold commas, line breaks and doubled quotes.
    static func csvRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var characters = text.makeIterator()
        var pending: Character?
        while let character = pending ?? characters.next() {
            pending = nil
            if inQuotes {
                if character == "\"" {
                    if let next = characters.next() {
                        if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n", "\r\n", "\r":
                    row.append(field); field = ""
                    rows.append(row); row = []
                default: field.append(character)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    // MARK: - JSON

    /// One entry as the JSON export writes it; everything but mood, flavour and timestamp may be missing (older exports).
    private struct Row: Decodable {
        let mood: Double?
        let flavour: Double?
        let title: String?
        let note: String?
        let timestamp: String?
        let localDate: String?
        let tags: [String]?
        let tagModelVersion: String?
    }

    /// Reads an export JSON: a list of entries. Tags keep where they came from (`tagModelVersion`), so tags picked by
    /// hand stay hand-picked.
    static func entries(fromJSON data: Data) throws -> Result {
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else { throw ImportError.notAnExport }
        var result = Result(entries: [], skipped: 0)
        for row in rows {
            if let entry = makeEntry(mood: row.mood, flavour: row.flavour, title: row.title, note: row.note,
                                     timestamp: row.timestamp.flatMap(parseDate), localDate: row.localDate,
                                     tags: row.tags ?? [], tagModelVersion: row.tagModelVersion) {
                result.entries.append(entry)
            } else {
                result.skipped += 1
            }
        }
        return result
    }

    // MARK: - Shared

    /// Builds an entry, or nil when a required value is missing or out of range. A missing or malformed day is taken
    /// from the timestamp in the current time zone; tags outside the vocabulary are dropped.
    private static func makeEntry(mood: Double?, flavour: Double?, title: String?, note: String?, timestamp: Date?,
                                  localDate: String?, tags: [String], tagModelVersion: String?) -> MoodEntry? {
        guard let mood, MoodScale.range.contains(mood),
              let flavour, (0...1).contains(flavour),
              let timestamp else { return nil }
        let day = localDate.flatMap { isLocalDate($0) ? $0 : nil }
        let known = tags.filter { MoodTag(rawValue: $0) != nil }
        return MoodEntry(id: nil, mood: mood, flavour: flavour,
                         title: title?.isEmpty == false ? title : nil,
                         note: note?.isEmpty == false ? note : nil,
                         timestamp: timestamp, localDate: day, tags: known,
                         tagModelVersion: known.isEmpty ? nil : tagModelVersion)
    }

    private static func isLocalDate(_ value: String) -> Bool {
        value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }

    /// ISO 8601, with or without fractional seconds (CSV exports have them, JSON exports don't).
    private static func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return fractional.date(from: trimmed) ?? whole.date(from: trimmed)
    }

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let whole: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
