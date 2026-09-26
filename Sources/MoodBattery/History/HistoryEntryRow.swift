import SwiftUI

struct HistoryEntryRow: View {
    let entry: MoodEntry

    @State private var isHovered = false

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

    private var displayTitle: String {
        if let title = entry.title, !title.isEmpty {
            return title
        }
        if let note = entry.note, !note.isEmpty {
            return String(note.prefix(50))
        }
        return MoodState.label(mood: entry.mood, flavour: entry.flavour)
    }

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(MoodColor.color(mood: entry.mood, flavour: entry.flavour))
                .frame(width: 5)

            VStack(spacing: 1) {
                Text(Self.dayFormatter.string(from: entry.timestamp))
                    .font(.system(size: 13, weight: .semibold))
                Text(Self.monthFormatter.string(from: entry.timestamp))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28)

            Text(displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
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
        HistoryEntryRow(entry: MoodEntry(id: 1, mood: 72, flavour: 0.2, title: "Good day", note: "Good day at work", timestamp: Date()))
        HistoryEntryRow(entry: MoodEntry(id: 2, mood: 20, flavour: 0.5, title: nil, note: nil, timestamp: Date()))
    }
    .padding()
    .frame(width: 260)
}
