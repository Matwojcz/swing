import Foundation

/// Search rules shared by the history filter and the detail-panel highlighting, so what is found is exactly
/// what gets highlighted. Pure domain logic — no views, no persistence.
///
/// Everything matches by whole words, ignoring case and accents: "low" never finds "slow", and "lift" never finds
/// "lifted". A query is a list of terms that must all match. A term is one word, or a two-word band name of the
/// current lens ("very low", "balanced lifted"), which is read as one unit.
enum EntrySearch {
    /// One search term: its folded words, in order.
    typealias Term = [String]

    /// The terms of a query in the given lens; an empty result means "not searching".
    static func terms(in query: String, lens: Lens) -> [Term] {
        let words = tokens(in: query).map(\.word)
        let phrases = phraseNames(lens: lens)
        var terms: [Term] = []
        var i = 0
        while i < words.count {
            // The longest band name starting here, else the single word.
            var length = 1
            for candidate in stride(from: min(phrases.maxLength, words.count - i), through: 2, by: -1)
            where phrases.names.contains(Array(words[i..<i + candidate])) {
                length = candidate
                break
            }
            terms.append(Array(words[i..<i + length]))
            i += length
        }
        return terms
    }

    /// Whether every term matches the entry: as consecutive words of its title or note, as one of its tags, or as one
    /// of `names`, the day's names in the current lens (`MoodState.searchNames`).
    static func matches(_ entry: MoodEntry, terms: [Term], names: [String]) -> Bool {
        guard !terms.isEmpty else { return false }
        let title = tokens(in: entry.title ?? "").map(\.word)
        let note = tokens(in: entry.note ?? "").map(\.word)
        let nameTerms = names.map { tokens(in: $0).map(\.word) }
        return terms.allSatisfy { term in
            contains(title, term) || contains(note, term) || nameTerms.contains(term)
                || entry.moodTags.contains { isTag($0, term) }
        }
    }

    /// Whether the term is exactly this tag.
    static func isTag(_ tag: MoodTag, _ term: Term) -> Bool {
        term == [tag.rawValue]
    }

    /// The terms that match one of `names` exactly, for highlighting the day's label: a flavour or cycle word in the
    /// label isn't searched, so it isn't highlighted either.
    static func nameTerms(_ terms: [Term], names: [String]) -> [Term] {
        let nameTerms = names.map { tokens(in: $0).map(\.word) }
        return terms.filter { nameTerms.contains($0) }
    }

    /// Every whole-word occurrence of every term in `text`, for highlighting. A two-word term spans both words and
    /// whatever sits between them ("balanced, lifted").
    static func ranges(of terms: [Term], in text: String) -> [Range<String.Index>] {
        let words = tokens(in: text)
        var result: [Range<String.Index>] = []
        for term in terms where !term.isEmpty && term.count <= words.count {
            for start in 0...(words.count - term.count)
            where words[start..<start + term.count].map(\.word) == term {
                result.append(words[start].range.lowerBound..<words[start + term.count - 1].range.upperBound)
            }
        }
        return result
    }

    // MARK: - Words

    /// The words of `text` with where they sit: runs of letters, digits and inner apostrophes ("didn't"), folded to
    /// lower case without accents for comparing.
    private static func tokens(in text: String) -> [(word: String, range: Range<String.Index>)] {
        var result: [(word: String, range: Range<String.Index>)] = []
        var start: String.Index?
        var index = text.startIndex
        func close(at end: String.Index) {
            guard let begin = start else { return }
            start = nil
            // Apostrophes at either end are quote marks, not part of the word.
            var lower = begin, upper = end
            while lower < upper, isApostrophe(text[lower]) { lower = text.index(after: lower) }
            while lower < upper, isApostrophe(text[text.index(before: upper)]) { upper = text.index(before: upper) }
            guard lower < upper else { return }
            result.append((fold(text[lower..<upper]), lower..<upper))
        }
        while index < text.endIndex {
            let character = text[index]
            if character.isLetter || character.isNumber || isApostrophe(character) {
                if start == nil { start = index }
            } else {
                close(at: index)
            }
            index = text.index(after: index)
        }
        close(at: text.endIndex)
        return result
    }

    private static func isApostrophe(_ character: Character) -> Bool {
        character == "'" || character == "’"
    }

    private static func fold(_ word: Substring) -> String {
        word.replacingOccurrences(of: "’", with: "'")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Whether `term` appears in `words` as consecutive words.
    private static func contains(_ words: [String], _ term: Term) -> Bool {
        guard !term.isEmpty, term.count <= words.count else { return false }
        return (0...(words.count - term.count)).contains { Array(words[$0..<$0 + term.count]) == term }
    }

    /// The lens's band names of two words or more, as folded words, and the longest one's length.
    private static func phraseNames(lens: Lens) -> (names: Set<[String]>, maxLength: Int) {
        phrasesByLens[lens] ?? ([], 1)
    }

    private static let phrasesByLens: [Lens: (names: Set<[String]>, maxLength: Int)] = Dictionary(
        uniqueKeysWithValues: Lens.allCases.map { lens in
            let names = Set(MoodState.allSearchNames(lens: lens).map { tokens(in: $0).map(\.word) }.filter { $0.count > 1 })
            return (lens, (names, names.map(\.count).max() ?? 1))
        }
    )
}
