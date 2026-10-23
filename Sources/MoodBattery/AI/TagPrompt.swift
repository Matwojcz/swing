import Foundation

/// Builds the prompt sent to the local model and parses/validates its reply against the closed
/// tag set. Pure string logic — no model dependency — so it is unit-testable on its own and shared
/// by every `EntryClassifier` implementation (the real one and the stub).
enum TagPrompt {
    /// Hard cap on tags per entry (decision: multi-label, max 3).
    static let maxTags = 3

    /// Fixed system instruction describing the task and the allowed tags. Versioned in the repo;
    /// treat changes as a taxonomy/model version bump so entries get re-classified.
    static var system: String {
        """
        You tag short personal mood-diary entries. Choose the tags that clearly describe how the \
        writer felt that day. Only use tags from this exact list, nothing else:
        \(MoodTag.promptList).
        Rules: pick at most \(maxTags) tags, and only ones that clearly apply — if unsure, pick \
        fewer or none. Do not invent tags. Reply with only the tags, comma-separated, lowercase, \
        with no other words or punctuation.
        """
    }

    /// Composes the user turn from an entry's title and note.
    static func user(title: String?, note: String?) -> String {
        let parts = [title, note]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let body = parts.isEmpty ? "(empty entry)" : parts.joined(separator: "\n")
        return "Entry:\n\(body)\n\nTags:"
    }

    /// Extracts valid tags from the model's raw reply: splits on anything that isn't a letter,
    /// maps each token onto the closed set, drops unknowns and duplicates, and caps at `maxTags`
    /// preserving first-seen order. Robust to a model that adds stray words or punctuation.
    static func parse(_ raw: String) -> [MoodTag] {
        var seen = Set<MoodTag>()
        var result: [MoodTag] = []
        for token in raw.lowercased().split(whereSeparator: { !$0.isLetter }) {
            guard let tag = MoodTag.from(String(token)), seen.insert(tag).inserted else { continue }
            result.append(tag)
            if result.count == maxTags { break }
        }
        return result
    }
}
