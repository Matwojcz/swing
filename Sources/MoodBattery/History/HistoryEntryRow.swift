import SwiftUI

struct HistoryEntryRow: View {
    let entry: MoodEntry

    @State private var isHovered = false
    @AppStorage(Lens.storageKey) private var lens: Lens = .none

    private static let chipFontSize: CGFloat = 10
    private static let spacing: CGFloat = 10
    private static let horizontalPadding: CGFloat = 12
    private static let colourBarWidth: CGFloat = 5
    private static let dateWidth: CGFloat = 28

    /// Narrowest width at which any entry's tags fit on one line: colour bar, date, the widest possible
    /// chip row and the time, with the spacing and padding between them.
    static var minimumWidth: CGFloat {
        let timeWidth: CGFloat = ceil(("00:00" as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width)
        let content: CGFloat = colourBarWidth + dateWidth + MoodTagChips.widestRowWidth(fontSize: chipFontSize) + timeWidth
        let gaps: CGFloat = spacing * 3 + horizontalPadding * 2
        return content + gaps
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    /// Returns the entry's title, falling back to a note prefix, then a mood state label.
    private var displayTitle: String {
        if let title = entry.title, !title.isEmpty {
            return title
        }
        if let note = entry.note, !note.isEmpty {
            return String(note.prefix(50))
        }
        return MoodState.label(mood: entry.mood, flavour: entry.flavour, lens: lens)
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            Capsule()
                .fill(MoodColor.color(mood: entry.mood, flavour: entry.flavour))
                .frame(width: Self.colourBarWidth)

            VStack(spacing: 1) {
                Text(Self.dayFormatter.string(from: entry.timestamp))
                    .font(.system(size: 13, weight: .semibold))
                Text(Self.monthFormatter.string(from: entry.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(width: Self.dateWidth)

            VStack(alignment: .leading, spacing: 5) {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if !entry.moodTags.isEmpty {
                    MoodTagChips(tags: entry.moodTags, fontSize: Self.chipFontSize)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Self.horizontalPadding)
        .modifier(GlassRowModifier(isHovered: isHovered))
        .onHover { isHovered = $0 }
    }
}

private struct GlassRowModifier: ViewModifier {
    let isHovered: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(isHovered ? .regular.interactive() : .regular, in: .rect(cornerRadius: 12))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.tankSurface)
                )
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        HistoryEntryRow(entry: MoodEntry(id: 1, mood: 7.2, flavour: 0.2, title: "Early start, eight designs, and a day full of big ideas",
                                         note: "Good day at work", timestamp: Date(), tags: ["energised", "excited", "happy", "content"]))
        HistoryEntryRow(entry: MoodEntry(id: 2, mood: 20, flavour: 0.5, title: nil, note: nil, timestamp: Date()))
    }
    .padding()
    .frame(width: 260)
}
