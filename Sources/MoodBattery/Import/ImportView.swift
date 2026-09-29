import SwiftUI

struct EditableImportEntry: Identifiable {
    let id = UUID()
    var mood: Double
    var flavour: Double
    var title: String
    var note: String
    var timestamp: Date

    init(parsed: MarkdownImporter.ParsedEntry) {
        self.mood = parsed.mood
        self.flavour = parsed.flavour
        self.title = parsed.title
        self.note = parsed.note
        self.timestamp = parsed.timestamp
    }
}

struct ImportPreviewSheet: View {
    @Binding var entries: [EditableImportEntry]
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var selectedId: UUID?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                entryList
                    .frame(minWidth: 300)
                if let selectedId,
                   let index = entries.firstIndex(where: { $0.id == selectedId }) {
                    entryEditor(for: index)
                        .frame(minWidth: 320)
                } else {
                    Text("Select an entry to review")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Review imported entries")
                    .font(.headline)
                Text("\(entries.count) entries found — adjust mood and flavour before importing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", action: onCancel)
            Button("Import all", action: onConfirm)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var entryList: some View {
        List(entries, selection: $selectedId) { entry in
            HStack(spacing: 10) {
                Capsule()
                    .fill(MoodColor.color(mood: entry.mood, flavour: entry.flavour))
                    .frame(width: 5, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dateFormatter.string(from: entry.timestamp))
                        .font(.system(size: 12, weight: .semibold))
                    Text(entry.title.isEmpty ? String(entry.note.prefix(60)) : entry.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(MoodScale.format(entry.mood))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .tag(entry.id)
        }
    }

    private func entryEditor(for index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.dateFormatter.string(from: entries[index].timestamp))
                    .font(.headline)

                TextField("Title", text: $entries[index].title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Mood")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(MoodScale.format(entries[index].mood))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Slider(value: $entries[index].mood, in: MoodScale.range, step: MoodScale.step)

                    HStack {
                        Text("Flavour")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(flavourLabel(entries[index].flavour))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Slider(value: $entries[index].flavour, in: 0...1)
                }

                Capsule()
                    .fill(MoodColor.color(mood: entries[index].mood, flavour: entries[index].flavour))
                    .frame(height: 6)

                Text("Note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entries[index].note)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
            }
            .padding()
        }
    }

    private func flavourLabel(_ v: Double) -> String {
        if v < 0.35 { return "calm" }
        if v > 0.65 { return "irritable" }
        return "normal"
    }
}
