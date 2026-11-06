import SwiftUI

extension EntrySearch {
    /// Returns `text` with every occurrence of the terms given a highlight background.
    static func highlighted(_ text: String, terms: [Term]) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges(of: terms, in: text) {
            if let target = Range(range, in: attributed) {
                attributed[target].backgroundColor = .yellow.opacity(0.35)
            }
        }
        return attributed
    }
}
