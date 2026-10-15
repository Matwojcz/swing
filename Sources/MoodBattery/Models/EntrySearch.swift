import Foundation

/// Free-text search over diary entries. Pure domain logic — no dependencies on views or persistence.
enum EntrySearch {
    /// Splits a query into its whitespace-separated words; an empty result means "not searching".
    static func words(in query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Returns the entries whose title and note together contain every word of `query`,
    /// ignoring case and accents, in their original order. An empty query matches nothing.
    static func matches(_ entries: [MoodEntry], query: String) -> [MoodEntry] {
        let terms = words(in: query)
        guard !terms.isEmpty else { return [] }
        return entries.filter { entry in
            let text = [entry.title, entry.note].compactMap { $0 }.joined(separator: "\n")
            return terms.allSatisfy {
                text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}
