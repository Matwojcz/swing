import Foundation

/// A dependency-free classifier: simple keyword / synonym matching, no model.
///
/// Its job is to let the pipeline and UI run *before* the llama.cpp model is wired in, and to act
/// as a graceful fallback if the model is unavailable. It is deliberately dumb — it only catches
/// literal cues, has no contextual understanding, and will miss paraphrased feelings — but it never
/// invents tags and respects the max-3 cap, so everything downstream can be built and tested now.
struct KeywordClassifier: EntryClassifier {
    /// Cue words/phrases that map onto each tag. Checked as plain substrings, lowercased.
    private static let cues: [MoodTag: [String]] = [
        .low: ["low", "down", "depressed", "sad", "blue", "miserable"],
        .flat: ["flat", "meh", "blank", "dull", "indifferent"],
        .numb: ["numb", "empty", "hollow", "disconnected", "detached"],
        .tired: ["tired", "exhausted", "sleepy", "worn out", "fatigued"],
        .foggy: ["foggy", "fog", "unfocused", "scattered", "hazy", "cloudy head"],
        .lonely: ["lonely", "alone", "isolated", "left out"],
        .anxious: ["anxious", "anxiety", "worried", "nervous", "panic", "on edge", "dread"],
        .restless: ["restless", "wired", "fidgety", "antsy", "can't sit", "cannot sit still"],
        .overwhelmed: ["overwhelmed", "too much", "swamped", "drowning"],
        .irritable: ["irritable", "irritated", "annoyed", "snappy", "touchy"],
        .frustrated: ["frustrated", "frustrating", "stuck", "fed up"],
        .angry: ["angry", "furious", "rage", "mad", "pissed"],
        .calm: ["calm", "peaceful", "relaxed", "settled", "at ease"],
        .content: ["content", "satisfied", "fine with", "okay with"],
        .rested: ["rested", "refreshed", "slept well", "well rested"],
        .happy: ["happy", "glad", "good day", "joy", "cheerful", "great day"],
        .hopeful: ["hopeful", "optimistic", "looking forward", "better days"],
        .energised: ["energised", "energized", "energetic", "motivated", "productive"],
        .excited: ["excited", "buzzing", "thrilled", "can't wait"],
        .okay: ["okay", "alright", "normal", "nothing special", "fine"],
    ]

    func classify(title: String?, note: String?) async throws -> [MoodTag] {
        let text = [title, note].compactMap { $0 }.joined(separator: "\n").lowercased()
        guard !text.isEmpty else { return [] }
        var result: [MoodTag] = []
        for tag in MoodTag.allCases {
            guard let cues = Self.cues[tag] else { continue }
            if cues.contains(where: { text.contains($0) }) {
                result.append(tag)
                if result.count == TagPrompt.maxTags { break }
            }
        }
        return result
    }
}
