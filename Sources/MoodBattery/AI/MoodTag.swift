import Foundation

/// The closed, vernacular tag vocabulary the on-device classifier may assign to an entry.
///
/// Two-dimensional (valence × arousal), feelings only, neutral core. Clinical words
/// (`depressed`, `euphoric`, `manic`, …) are intentionally NOT here — they belong to the
/// opt-in Bipolar lens, a later phase. The model may only ever return members of this set.
/// See `docs/AI_TAGGING_PLAN.md`.
enum MoodTag: String, CaseIterable, Codable, Identifiable, Hashable {
    // low valence · low arousal
    case low, flat, numb, tired, foggy, lonely
    // low valence · high arousal
    case anxious, restless, overwhelmed, irritable, frustrated, angry
    // high valence · low arousal
    case calm, content, rested
    // high valence · high arousal
    case happy, hopeful, energised, excited
    // neutral
    case okay

    var id: String { rawValue }

    /// The full allowed vocabulary as a comma-separated list, for the model prompt.
    static var promptList: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }

    /// Case-insensitive lookup from a single raw word the model emitted; nil if not a valid tag.
    static func from(_ word: String) -> MoodTag? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first { $0.rawValue == trimmed }
    }
}
