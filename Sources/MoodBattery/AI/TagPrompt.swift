import Foundation

/// Builds the prompt sent to the local model and parses/validates its reply against the closed
/// tag set. Pure string logic — no model dependency — so it is unit-testable on its own and shared
/// by every `EntryClassifier` implementation (the real one and the stub).
enum TagPrompt {
    /// Bump whenever the prompt, schema or merge rules change, so already-tagged entries count as stale.
    static let version = "split-v2"

    /// Tags the model may pick for each part of the day (earlier / by the end).
    static let maxTagsPerPart = 2
    /// Hard cap on tags per entry: a steady day collapses to 1-2, only a day whose mood shifts reaches 4.
    static let maxTags = maxTagsPerPart * 2

    /// Fixed system instruction describing the task and the allowed tags. Versioned in the repo;
    /// treat changes as a taxonomy/model version bump so entries get re-classified.
    static var system: String {
        """
        You tag mood-diary entries. Describe in a few words how the writer felt earlier in the day and \
        pick 1-\(maxTagsPerPart) tags for it, then describe how they felt by the end of the day and pick \
        1-\(maxTagsPerPart) tags for that. Tags come from ONLY this list:
        \(MoodTag.promptList)
        If the day stayed the same throughout, use the same tags for both parts. Tag only feelings the \
        writer states or clearly shows. A busy day, a short night or lots of activity is not tiredness or \
        stress unless the writer says they felt that way. Only use "okay" for a genuinely ordinary, neutral day.
        Relief that something hard is over is not calm: tag how the writer actually is at that point. If the writer \
        qualifies a word, like "tired in a good way", tag the feeling they mean, not the word.
        Pick the most specific tag for each feeling:
        anxious = worry, fear or nerves about what might happen; frustrated = blocked, let down, things not going right; \
        irritable = short-tempered, easily annoyed; angry = anger at someone or something; low = sad, teary, down; \
        flat = muted, nothing feels like much; numb = unable to feel anything; lonely = missing people or closeness; \
        restless = unable to settle; overwhelmed = too much at once; tired = worn out, sleepy or drained.
        calm = genuinely settled and at ease, not just relieved.
        Reply with only a JSON object like {"earlier": "...", "earlier_tags": ["..."], "later": "...", "later_tags": ["..."]}.

        Example entry: "Felt shaky all morning, couldn't focus at work, everything felt pointless by evening"
        Example reply: {"earlier": "shaky, unfocused", "earlier_tags": ["anxious", "foggy"], "later": "hopeless", "later_tags": ["low"]}

        Example entry: "Grey, sluggish morning and couldn't get going, then a lovely dinner with friends that really lifted me"
        Example reply: {"earlier": "sluggish, grey", "earlier_tags": ["flat"], "later": "lifted, warm", "later_tags": ["happy"]}

        Example entry: "Busy day at work with lots to get through, but it flowed nicely, then drinks with friends and lots of laughs"
        Example reply: {"earlier": "steady, in the flow", "earlier_tags": ["calm"], "later": "cheerful, warm", "later_tags": ["happy"]}

        Example entry: "Exhausted and low all day, stayed in bed, still feeling empty at night"
        Example reply: {"earlier": "exhausted, low", "earlier_tags": ["tired", "low"], "later": "empty", "later_tags": ["low", "flat"]}

        Example entry: "Panic attack on the train this morning and I had to go home. It passed by the evening and I was relieved, but still shaky and completely drained"
        Example reply: {"earlier": "panicky, frightened", "earlier_tags": ["anxious"], "later": "relieved but shaky, drained", "later_tags": ["tired", "anxious"]}

        Example entry: "Just a normal Tuesday, nothing special happened"
        Example reply: {"earlier": "ordinary", "earlier_tags": ["okay"], "later": "ordinary", "later_tags": ["okay"]}
        """
    }

    /// JSON schema the model's output is grammar-constrained to. Property order matters: each part's
    /// description is generated before its tags, so the tags are picked right after the model has named the feeling.
    static var schema: String {
        let names = MoodTag.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ",")
        let tagArray = """
        {"type":"array","items":{"type":"string","enum":[\(names)]},"minItems":1,"maxItems":\(maxTagsPerPart)}
        """
        return """
        {"type":"object","properties":{"earlier":{"type":"string","maxLength":60},"earlier_tags":\(tagArray),\
        "later":{"type":"string","maxLength":60},"later_tags":\(tagArray)},\
        "required":["earlier","earlier_tags","later","later_tags"]}
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

    /// The model's structured reply: a short description and tags for each part of the day.
    struct DayReply: Decodable {
        let earlier: String
        let earlierTags: [String]
        let later: String
        let laterTags: [String]

        enum CodingKeys: String, CodingKey {
            case earlier, later
            case earlierTags = "earlier_tags"
            case laterTags = "later_tags"
        }
    }

    /// Decodes the model's JSON reply and merges both parts of the day: earlier tags first, then the
    /// end-of-day tags, deduplicated, each validated against the closed set. `okay` only survives as the sole tag.
    static func parse(_ raw: String) -> [MoodTag] {
        guard let data = raw.data(using: .utf8),
              let reply = try? JSONDecoder().decode(DayReply.self, from: data) else { return [] }
        var merged: [MoodTag] = []
        for word in reply.earlierTags.prefix(maxTagsPerPart) + reply.laterTags.prefix(maxTagsPerPart) {
            if let tag = MoodTag.from(word), !merged.contains(tag) {
                merged.append(tag)
            }
        }
        let withoutFiller = merged.filter { $0 != .okay }
        return withoutFiller.isEmpty ? merged : withoutFiller
    }
}
