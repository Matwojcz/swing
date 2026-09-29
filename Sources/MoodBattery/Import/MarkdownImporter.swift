import Foundation

struct MarkdownImporter {
    struct ParsedEntry {
        var mood: Double
        var flavour: Double
        var title: String
        var note: String
        var timestamp: Date
    }

    enum ImportError: LocalizedError {
        case noEntriesFound
        case fileUnreadable(String)

        var errorDescription: String? {
            switch self {
            case .noEntriesFound:
                return "No diary entries with dates found in this file."
            case .fileUnreadable(let path):
                return "Couldn't read file at \(path)."
            }
        }
    }

    private let store = MoodEntryStore()

    func importFile(at url: URL) throws -> Int {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.fileUnreadable(url.path)
        }
        let entries = parse(content)
        if entries.isEmpty { throw ImportError.noEntriesFound }
        for parsed in entries {
            let entry = MoodEntry(
                id: nil,
                mood: parsed.mood,
                flavour: parsed.flavour,
                note: parsed.note.isEmpty ? nil : parsed.note,
                timestamp: parsed.timestamp
            )
            try store.save(entry)
        }
        return entries.count
    }

    // MARK: - Parsing

    func parse(_ content: String) -> [ParsedEntry] {
        let lines = content.components(separatedBy: .newlines)
        var inDiarySection = false
        var entries: [ParsedEntry] = []
        var currentDate: Date?
        var currentTitle: String = ""
        var currentBody: [String] = []

        func flush() {
            guard let date = currentDate else { return }
            var noteLines: [String] = []
            var explicitMood: Double?
            var explicitFlavour: Double?

            for line in currentBody {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let val = parseField(trimmed, name: "mood") ?? parseField(trimmed, name: "energy") {
                    explicitMood = max(MoodScale.min, min(MoodScale.max, val))
                } else if let val = parseField(trimmed, name: "flavour") ?? parseField(trimmed, name: "flavor") {
                    explicitFlavour = max(0, min(1, val))
                } else {
                    noteLines.append(line)
                }
            }

            let body = noteLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fullText = currentTitle.isEmpty ? body : (body.isEmpty ? currentTitle : "\(currentTitle)\n\n\(body)")
            entries.append(ParsedEntry(
                mood: explicitMood ?? estimateMood(from: fullText),
                flavour: explicitFlavour ?? estimateFlavour(from: fullText),
                title: currentTitle,
                note: body,
                timestamp: date
            ))
            currentDate = nil
            currentTitle = ""
            currentBody = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                if trimmed.lowercased().contains("diary entries") ||
                   trimmed.lowercased().contains("diary") && trimmed.lowercased().contains("entr") {
                    inDiarySection = true
                    continue
                } else if inDiarySection {
                    flush()
                    inDiarySection = false
                    continue
                }
            }

            guard inDiarySection else { continue }

            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                flush()
                let headingText = trimmed
                    .replacingOccurrences(of: "^#{1,3}\\s+", with: "", options: .regularExpression)
                if let date = parseDiaryDate(from: headingText) {
                    currentDate = date
                    let titlePart = extractTitle(from: headingText)
                    currentTitle = titlePart
                } else {
                    if currentDate != nil {
                        currentBody.append(trimmed)
                    }
                }
            } else if trimmed == "---" {
                continue
            } else if currentDate != nil {
                currentBody.append(line)
            }
        }
        flush()

        return entries
    }

    // MARK: - Date parsing

    private static let monthNames: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4,
        "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
    ]

    private static let diaryDateRegex = try! NSRegularExpression(
        pattern: #"(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(\d{1,2})\s+(\w+)\s+(\d{4})"#,
        options: .caseInsensitive
    )

    private static let rangedDateRegex = try! NSRegularExpression(
        pattern: #"(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(\d{1,2})\s*[–—-]\s*(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(\d{1,2})\s+(\w+)\s+(\d{4})"#,
        options: .caseInsensitive
    )

    private static let shortRangeRegex = try! NSRegularExpression(
        pattern: #"(\d{1,2})\s*[–—-]\s*(?:\w+\s+)?(\d{1,2})\s+(\w+)\s+(\d{4})"#,
        options: .caseInsensitive
    )

    private func parseDiaryDate(from text: String) -> Date? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        if let match = Self.rangedDateRegex.firstMatch(in: text, range: fullRange) {
            let day2 = nsText.substring(with: match.range(at: 2))
            let monthStr = nsText.substring(with: match.range(at: 3))
            let yearStr = nsText.substring(with: match.range(at: 4))
            return buildDate(day: day2, month: monthStr, year: yearStr)
        }

        if let match = Self.diaryDateRegex.firstMatch(in: text, range: fullRange) {
            let dayStr = nsText.substring(with: match.range(at: 1))
            let monthStr = nsText.substring(with: match.range(at: 2))
            let yearStr = nsText.substring(with: match.range(at: 3))
            return buildDate(day: dayStr, month: monthStr, year: yearStr)
        }

        if let match = Self.shortRangeRegex.firstMatch(in: text, range: fullRange) {
            let day2 = nsText.substring(with: match.range(at: 2))
            let monthStr = nsText.substring(with: match.range(at: 3))
            let yearStr = nsText.substring(with: match.range(at: 4))
            return buildDate(day: day2, month: monthStr, year: yearStr)
        }

        return nil
    }

    private func buildDate(day: String, month: String, year: String) -> Date? {
        guard let dayNum = Int(day),
              let monthNum = Self.monthNames[month.lowercased()],
              let yearNum = Int(year) else { return nil }
        var components = DateComponents()
        components.year = yearNum
        components.month = monthNum
        components.day = dayNum
        components.hour = 12
        return Calendar.current.date(from: components)
    }

    private func extractTitle(from heading: String) -> String {
        guard let dashRange = heading.range(of: " — ") ?? heading.range(of: " - ") else {
            return ""
        }
        return String(heading[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Field parsing

    private func parseField(_ line: String, name: String) -> Double? {
        let lower = line.lowercased()
        guard lower.hasPrefix("\(name):") else { return nil }
        let valueStr = line.dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces)
        return Double(valueStr)
    }

    // MARK: - Mood estimation

    private func estimateMood(from text: String) -> Double {
        let lower = text.lowercased()
        var score = MoodScale.baseline

        let depressiveSignals: [(String, Double)] = [
            ("depressive", -1.8), ("depressed", -1.8), ("hopeless", -1.5),
            ("crying", -1.0), ("cried", -1.0), ("teary", -0.8), ("tears", -0.8),
            ("exhausted", -1.2), ("exhaustion", -1.2), ("jelly legs", -1.4),
            ("couldn't do anything", -1.5), ("unable to", -1.0),
            ("no energy", -1.5), ("low energy", -1.2), ("so tired", -1.2),
            ("anhedonia", -1.6), ("felt nothing", -1.4), ("joyless", -1.4),
            ("isolation", -1.0), ("isolated", -1.0), ("withdrew", -1.0),
            ("worthless", -1.6), ("debilitated", -1.6), ("flat", -1.0),
            ("sad", -0.8), ("sadness", -0.8), ("drained", -1.0),
            ("anxiety attack", -1.2), ("panic attack", -1.4),
            ("self-harm", -1.8), ("suicid", -2.0), ("ending my life", -2.0),
            ("slug mode", -1.2), ("not giving a shit", -0.8),
            ("heavy comedown", -1.2), ("fragile", -0.8),
        ]

        let elevatedSignals: [(String, Double)] = [
            ("wired", 1.5), ("racing thoughts", 1.4), ("hyper", 1.4),
            ("euphori", 1.4), ("god mode", 1.8), ("unstoppable", 1.6),
            ("high energy", 1.4), ("manic", 1.6), ("elevated", 1.2),
            ("couldn't sleep", 1.0), ("can't sleep", 1.0),
            ("sharp", 0.8), ("fast and wired", 1.6),
            ("razor sharp", 1.4), ("electric sensation", 1.2),
            ("tingling", 1.0), ("sweaty hands", 0.8),
            ("talking too fast", 1.2), ("too loud", 1.0),
            ("impulsive", 1.0), ("obsess", 1.0), ("preoccup", 1.0),
            ("high day", 1.4), ("up-day", 1.4),
        ]

        let baselineSignals: [(String, Double)] = [
            ("baseline", 0), ("settled", -0.2), ("normal", -0.1),
            ("quiet day", -0.3), ("uneventful", -0.3), ("solid day", -0.1),
            ("properly normal", -0.2), ("content", 0.2), ("rested", 0.1),
            ("productive", 0.3), ("good day", 0.3), ("lovely", 0.2),
        ]

        for (word, delta) in depressiveSignals where lower.contains(word) {
            score += delta
        }
        for (word, delta) in elevatedSignals where lower.contains(word) {
            score += delta
        }
        for (word, delta) in baselineSignals where lower.contains(word) {
            score += delta
        }

        return max(MoodScale.min, min(MoodScale.max, score))
    }

    // MARK: - Flavour estimation

    private func estimateFlavour(from text: String) -> Double {
        let lower = text.lowercased()
        var irritableSignals = 0
        var happySignals = 0

        let irritableWords = [
            "irritable", "irritated", "angry", "anger", "agitated",
            "paranoi", "suspicious", "short fuse", "combative",
            "confrontation", "restless", "frustrat", "anxious", "anxiety",
            "tense", "snappy",
        ]
        let happyWords = [
            "happy", "joy", "lovely", "wonderful", "fun", "excited",
            "creative", "painting", "bass", "good day", "great day",
            "content", "warm", "hopeful", "calm", "peaceful", "pleasure",
        ]

        for word in irritableWords where lower.contains(word) { irritableSignals += 1 }
        for word in happyWords where lower.contains(word) { happySignals += 1 }

        let total = irritableSignals + happySignals
        if total == 0 { return 0.5 }
        return Double(irritableSignals) / Double(total)
    }
}
