import Foundation

/// Search rules shared by the history filter and the detail-panel highlighting, so what is found is exactly
/// what gets highlighted. Pure domain logic — no views, no persistence.
///
/// Everything matches by whole words, ignoring case and accents: "low" never finds "slow", and "lift" never finds
/// "lifted". A query is a list of terms that must all match. A mood word (a tag, or a band name of the current lens,
/// read as one unit when it has two words: "very low") finds tags and bands only, so "low" means a low day and never
/// "a low hum" in a note. Any other word finds the title and note only.
enum EntrySearch {
    /// One search term: its folded words, in order, and whether they name a tag or band.
    struct Term: Equatable {
        let words: [String]
        let isMoodWord: Bool
    }

    /// The terms of a query in the given lens; an empty result means "not searching".
    static func terms(in query: String, lens: Lens) -> [Term] {
        let words = tokens(in: query).map(\.word)
        let moodWords = moodWords(lens: lens)
        var terms: [Term] = []
        var i = 0
        while i < words.count {
            // The longest tag or band name starting here, else a plain word.
            var term = Term(words: [words[i]], isMoodWord: false)
            for length in stride(from: min(moodWords.maxLength, words.count - i), through: 1, by: -1)
            where moodWords.names.contains(Array(words[i..<i + length])) {
                term = Term(words: Array(words[i..<i + length]), isMoodWord: true)
                break
            }
            terms.append(term)
            i += term.words.count
        }
        return terms
    }

    /// Whether every term matches the entry: a mood word as one of its tags or one of `names`, the day's names in the
    /// current lens (`MoodState.searchNames`); any other word in its title or note.
    static func matches(_ entry: MoodEntry, terms: [Term], names: [String]) -> Bool {
        guard !terms.isEmpty else { return false }
        let title = tokens(in: entry.title ?? "").map(\.word)
        let note = tokens(in: entry.note ?? "").map(\.word)
        let nameTerms = names.map { tokens(in: $0).map(\.word) }
        return terms.allSatisfy { term in
            term.isMoodWord ? nameTerms.contains(term.words) || entry.moodTags.contains { isTag($0, term) }
                            : contains(title, term.words) || contains(note, term.words)
        }
    }

    /// Whether the term is exactly this tag.
    static func isTag(_ tag: MoodTag, _ term: Term) -> Bool {
        term.isMoodWord && term.words == [tag.rawValue]
    }

    /// The terms that match one of `names` exactly, for highlighting the day's label: a flavour or cycle word in the
    /// label isn't searched, so it isn't highlighted either.
    static func nameTerms(_ terms: [Term], names: [String]) -> [Term] {
        let nameTerms = names.map { tokens(in: $0).map(\.word) }
        return terms.filter { $0.isMoodWord && nameTerms.contains($0.words) }
    }

    /// The terms that search the title and note, for highlighting there.
    static func textTerms(_ terms: [Term]) -> [Term] {
        terms.filter { !$0.isMoodWord }
    }

    /// A short stretch of `text` around the first match, for showing why a search found the entry; nil without a match.
    static func excerpt(of text: String, terms: [Term]) -> String? {
        guard let match = ranges(of: terms, in: text).min(by: { $0.lowerBound < $1.lowerBound }) else { return nil }
        var start = text.index(match.lowerBound, offsetBy: -excerptLeadIn, limitedBy: text.startIndex) ?? text.startIndex
        if start > text.startIndex {
            // Begin on a whole word.
            let space = text[start..<match.lowerBound].firstIndex(where: \.isWhitespace)
            start = space.map { text.index(after: $0) } ?? match.lowerBound
        }
        let end = text.index(match.upperBound, offsetBy: excerptLeadOut, limitedBy: text.endIndex) ?? text.endIndex
        let excerpt = text[start..<end].replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return (start > text.startIndex ? "…" : "") + excerpt + (end < text.endIndex ? "…" : "")
    }

    private static let excerptLeadIn = 24
    private static let excerptLeadOut = 80

    /// Every whole-word occurrence of every term in `text`, for highlighting. A two-word term spans both words and
    /// whatever sits between them ("balanced, lifted").
    static func ranges(of terms: [Term], in text: String) -> [Range<String.Index>] {
        let words = tokens(in: text)
        var result: [Range<String.Index>] = []
        for term in terms.map(\.words) where !term.isEmpty && term.count <= words.count {
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
    private static func contains(_ words: [String], _ term: [String]) -> Bool {
        guard !term.isEmpty, term.count <= words.count else { return false }
        return (0...(words.count - term.count)).contains { Array(words[$0..<$0 + term.count]) == term }
    }

    /// The lens's tags and band names as folded words, and the longest one's length.
    private static func moodWords(lens: Lens) -> (names: Set<[String]>, maxLength: Int) {
        moodWordsByLens[lens] ?? ([], 1)
    }

    private static let moodWordsByLens: [Lens: (names: Set<[String]>, maxLength: Int)] = Dictionary(
        uniqueKeysWithValues: Lens.allCases.map { lens in
            let bands = MoodState.allSearchNames(lens: lens).map { tokens(in: $0).map(\.word) }
            let names = Set(bands + MoodTag.allCases.map { [$0.rawValue] })
            return (lens, (names, names.map(\.count).max() ?? 1))
        }
    )
}
