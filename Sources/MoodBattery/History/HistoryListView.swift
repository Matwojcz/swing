import SwiftUI

/// A minimal scrollable list of past entries: top and bottom edges fade out
/// so whatever sits in the vertical middle of the visible area reads as the
/// focused entry.
struct HistoryListView: View {
    let entries: [MoodEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                Text("No entries yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(entries) { entry in
                            HistoryEntryRow(entry: entry)
                        }
                    }
                    .padding(.vertical, 60)
                }
                .mask(fadeMask)
            }
        }
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.2),
                .init(color: .black, location: 0.8),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    HistoryListView(entries: (0..<10).map {
        MoodEntry(id: Int64($0), energy: Double.random(in: 0...100), flavour: 0.4, note: nil, timestamp: Date())
    })
    .frame(width: 240, height: 320)
}
