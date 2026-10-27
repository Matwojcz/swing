import SwiftUI

extension MoodTag {
    /// Tint by the tag's quadrant on the valence × arousal grid, taken from the mood gauge palette.
    var tint: Color {
        switch self {
        case .low, .flat, .numb, .tired, .foggy, .lonely:
            Color(red: 83 / 255, green: 74 / 255, blue: 183 / 255)
        case .anxious, .restless, .overwhelmed, .irritable, .frustrated, .angry:
            Color(red: 226 / 255, green: 75 / 255, blue: 74 / 255)
        case .calm, .content, .rested:
            Color(red: 72 / 255, green: 178 / 255, blue: 120 / 255)
        case .happy, .hopeful, .energised, .excited:
            Color(red: 239 / 255, green: 159 / 255, blue: 39 / 255)
        case .okay:
            Color(red: 55 / 255, green: 138 / 255, blue: 221 / 255)
        }
    }
}

struct MoodTagChip: View {
    let tag: MoodTag
    var fontSize: CGFloat = 11

    var body: some View {
        Text(tag.rawValue)
            .font(.system(size: fontSize, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, fontSize * 0.6)
            .padding(.vertical, fontSize * 0.2)
            .background(Capsule().fill(tag.tint.opacity(0.28)))
            .overlay(Capsule().stroke(tag.tint.opacity(0.55), lineWidth: 0.5))
    }
}

/// A row of tag chips.
struct MoodTagChips: View {
    let tags: [MoodTag]
    var fontSize: CGFloat = 11

    private static let spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(tags) { MoodTagChip(tag: $0, fontSize: fontSize) }
        }
    }

    /// Width of the widest possible row: the `TagPrompt.maxTags` widest chips in the vocabulary side by side.
    /// Layouts reserve this so every entry's tags fit without truncating.
    static func widestRowWidth(fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let chipWidths = MoodTag.allCases
            .map { ceil(($0.rawValue as NSString).size(withAttributes: [.font: font]).width) + fontSize * 1.2 }
            .sorted(by: >)
        let count = min(TagPrompt.maxTags, chipWidths.count)
        return chipWidths.prefix(count).reduce(0, +) + spacing * CGFloat(count - 1)
    }
}

#Preview {
    MoodTagChips(tags: [.overwhelmed, .frustrated, .irritable, .energised], fontSize: 10)
        .padding()
}
