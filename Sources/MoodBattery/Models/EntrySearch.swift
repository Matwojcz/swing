import Foundation

/// Free-text search rules shared by the database query and the detail-panel highlighting, so what
/// is found is exactly what gets highlighted. Pure domain logic — no views, no persistence.
enum EntrySearch {
    /// Case and accent-insensitive comparison used everywhere.
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Splits a query into its whitespace-separated words; an empty result means "not searching".
    static func words(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Whether `text` contains `term`, ignoring case and accents.
    static func contains(_ text: String, term: String) -> Bool {
        text.range(of: term, options: options) != nil
    }

    /// Every occurrence of every term in `text`, for highlighting. Ranges may overlap when terms do.
    static func ranges(of terms: [String], in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        for term in terms where !term.isEmpty {
            var searchRange = text.startIndex..<text.endIndex
            while let found = text.range(of: term, options: options, range: searchRange) {
                result.append(found)
                searchRange = found.upperBound..<text.endIndex
            }
        }
        return result
    }
}
