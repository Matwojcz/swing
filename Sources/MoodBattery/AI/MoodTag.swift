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

    /// Off-list words folded into the nearest tag. The grammar-constrained model can't emit these, so this
    /// only matters for an unconstrained classifier; avoids filler words ("good", "fine", "down", "normal").
    static let synonyms: [String: MoodTag] = [
        "tearful": .low, "teary": .low, "sad": .low, "upset": .low, "crying": .low, "gloomy": .low,
        "miserable": .low, "hopeless": .low, "depressed": .low, "useless": .low, "worthless": .low,
        "empty": .flat, "apathetic": .flat, "unmotivated": .flat, "detached": .flat,
        "exhausted": .tired, "drained": .tired, "fatigued": .tired, "sleepy": .tired,
        "groggy": .foggy, "confused": .foggy, "unfocused": .foggy,
        "isolated": .lonely,
        "worried": .anxious, "nervous": .anxious, "stressed": .anxious, "tense": .anxious,
        "panicky": .anxious, "scared": .anxious, "afraid": .anxious,
        "agitated": .restless, "fidgety": .restless,
        "swamped": .overwhelmed,
        "annoyed": .irritable, "grumpy": .irritable, "cranky": .irritable, "snappy": .irritable,
        "furious": .angry,
        "relaxed": .calm, "peaceful": .calm, "settled": .calm,
        "satisfied": .content, "grateful": .content,
        "refreshed": .rested,
        "joyful": .happy, "cheerful": .happy,
        "optimistic": .hopeful,
        "energized": .energised, "energetic": .energised,
        "thrilled": .excited,
        "neutral": .okay,
    ]

    /// Case-insensitive lookup from a single raw word the model emitted: an exact tag, else a known
    /// synonym, else nil.
    static func from(_ word: String) -> MoodTag? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return MoodTag(rawValue: trimmed) ?? synonyms[trimmed]
    }
}
