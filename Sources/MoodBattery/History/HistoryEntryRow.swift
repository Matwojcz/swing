import SwiftUI

/// A single past entry, styled as a minimal pill: a mood-colored accent bar
/// (echoing the tank's color language), a title, and a time/date stack.
struct HistoryEntryRow: View {
    let entry: MoodEntry

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var title: String {
        if let note = entry.note, !note.isEmpty {
            return note
        }
        return MoodState.label(energy: entry.energy, flavour: entry.flavour)
    }

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(MoodColor.color(energy: entry.energy, flavour: entry.flavour))
                .frame(width: 6)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 12, weight: .semibold))
                Text(Self.dateFormatter.string(from: entry.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.tankSurface)
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        HistoryEntryRow(entry: MoodEntry(id: 1, energy: 72, flavour: 0.2, note: "Good day at work", timestamp: Date()))
        HistoryEntryRow(entry: MoodEntry(id: 2, energy: 20, flavour: 0.5, note: nil, timestamp: Date()))
    }
    .padding()
    .frame(width: 260)
}
