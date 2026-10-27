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

/// A row of tag chips. With `compact`, shows as many chips as fit the width and folds the rest into "+N".
struct MoodTagChips: View {
    let tags: [MoodTag]
    var fontSize: CGFloat = 11
    var compact = false

    @State private var availableWidth: CGFloat = .infinity

    private static let spacing: CGFloat = 4

    var body: some View {
        if compact {
            let shown = fittingCount(in: availableWidth)
            row(Array(tags.prefix(shown)), hidden: tags.count - shown)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        } else {
            row(tags, hidden: 0)
        }
    }

    /// How many leading chips fit in `width`, leaving room for the "+N" label when some are left out.
    /// Measured from text widths rather than by laying out candidate rows, so the row is laid out once.
    private func fittingCount(in width: CGFloat) -> Int {
        let chipWidths = tags.map { textWidth($0.rawValue) + fontSize * 1.2 }
        for shown in stride(from: tags.count, through: 1, by: -1) {
            let hidden = tags.count - shown
            var total = chipWidths.prefix(shown).reduce(0, +) + Self.spacing * CGFloat(shown - 1)
            if hidden > 0 { total += Self.spacing + textWidth("+\(hidden)") }
            if total <= width { return shown }
        }
        return 1
    }

    private func textWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func row(_ shown: [MoodTag], hidden: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(shown) { MoodTagChip(tag: $0, fontSize: fontSize) }
            if hidden > 0 {
                Text("+\(hidden)")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MoodTagChips(tags: [.flat, .low, .happy, .content])
        MoodTagChips(tags: [.anxious, .overwhelmed, .calm, .hopeful], fontSize: 10, compact: true)
            .frame(width: 150, alignment: .leading)
    }
    .padding()
}
