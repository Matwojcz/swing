import Foundation

struct MarkdownImporter {
    struct ParsedEntry {
        var energy: Double
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
                energy: parsed.energy,
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
            var explicitEnergy: Double?
            var explicitFlavour: Double?

            for line in currentBody {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let val = parseField(trimmed, name: "energy") {
                    explicitEnergy = max(0, min(100, val))
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
                energy: explicitEnergy ?? estimateEnergy(from: fullText),
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

    // MARK: - Energy estimation

    private func estimateEnergy(from text: String) -> Double {
        let lower = text.lowercased()
        var score: Double = 50

        let depressiveSignals: [(String, Double)] = [
            ("depressive", -18), ("depressed", -18), ("hopeless", -15),
            ("crying", -10), ("cried", -10), ("teary", -8), ("tears", -8),
            ("exhausted", -12), ("exhaustion", -12), ("jelly legs", -14),
            ("couldn't do anything", -15), ("unable to", -10),
            ("no energy", -15), ("low energy", -12), ("so tired", -12),
            ("anhedonia", -16), ("felt nothing", -14), ("joyless", -14),
            ("isolation", -10), ("isolated", -10), ("withdrew", -10),
            ("worthless", -16), ("debilitated", -16), ("flat", -10),
            ("sad", -8), ("sadness", -8), ("drained", -10),
            ("anxiety attack", -12), ("panic attack", -14),
            ("self-harm", -18), ("suicid", -20), ("ending my life", -20),
            ("slug mode", -12), ("not giving a shit", -8),
            ("heavy comedown", -12), ("fragile", -8),
        ]

        let elevatedSignals: [(String, Double)] = [
            ("wired", 15), ("racing thoughts", 14), ("hyper", 14),
            ("euphori", 14), ("god mode", 18), ("unstoppable", 16),
            ("high energy", 14), ("manic", 16), ("elevated", 12),
            ("couldn't sleep", 10), ("can't sleep", 10),
            ("sharp", 8), ("fast and wired", 16),
            ("razor sharp", 14), ("electric sensation", 12),
            ("tingling", 10), ("sweaty hands", 8),
            ("talking too fast", 12), ("too loud", 10),
            ("impulsive", 10), ("obsess", 10), ("preoccup", 10),
            ("high day", 14), ("up-day", 14),
        ]

        let baselineSignals: [(String, Double)] = [
            ("baseline", 0), ("settled", -2), ("normal", -1),
            ("quiet day", -3), ("uneventful", -3), ("solid day", -1),
            ("properly normal", -2), ("content", 2), ("rested", 1),
            ("productive", 3), ("good day", 3), ("lovely", 2),
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

        return max(0, min(100, score))
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
