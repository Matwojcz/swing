import SwiftUI

struct EntryDetailPanel: View {
    let entry: MoodEntry
    var onClose: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private var moodLabel: String {
        MoodState.label(energy: entry.energy, flavour: entry.flavour)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Spacer()
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 4, y: 0)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: entry.timestamp))
                    .font(.system(size: 13, weight: .semibold))
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(MoodColor.color(energy: entry.energy, flavour: entry.flavour))
                    .frame(width: 6, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(moodLabel)
                        .font(.system(size: 14, weight: .semibold))
                    Text("Energy \(Int(entry.energy))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            GaugeView(energy: entry.energy, flavour: entry.flavour)
                .scaleEffect(0.55, anchor: .top)
                .frame(width: GaugeView.width * 0.55, height: GaugeView.height * 0.55)

            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
    }
}

#Preview {
    EntryDetailPanel(
        entry: MoodEntry(id: 1, energy: 72, flavour: 0.3, note: "Had a great morning, went for a run and felt really energized. The afternoon was calmer but still good overall.", timestamp: Date()),
        onClose: {}
    )
    .frame(height: 500)
}
