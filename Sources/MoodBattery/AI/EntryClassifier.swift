import Foundation

/// Abstraction over whatever assigns mood tags to an entry's text.
///
/// The app depends on this protocol, never on a particular model or runtime, so the on-device
/// LLM (llama.cpp + Qwen) can be swapped in without touching the UI or persistence — and a future
/// Windows port supplies its own conformance over the same llama.cpp core. This is the
/// cross-platform boundary from the plan.
protocol EntryClassifier {
    /// Returns up to `TagPrompt.maxTags` tags from the closed `MoodTag` set for the given entry text.
    /// Implementations must never return tags outside the set, and must not block the calling thread.
    func classify(title: String?, note: String?) async throws -> [MoodTag]
}
