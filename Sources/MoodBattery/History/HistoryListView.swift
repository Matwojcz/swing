import SwiftUI

struct HistoryListView: View {
    let entries: [MoodEntry]
    var selectedEntry: MoodEntry?
    var onSelect: ((MoodEntry) -> Void)?
    var onDelete: ((MoodEntry) -> Void)?
    var scrollToEntry: MoodEntry?

    var body: some View {
        Group {
            if entries.isEmpty {
                Text("No entries yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    ScrollViewReader { scrollProxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                Spacer(minLength: 40)
                                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                    HistoryEntryRow(entry: entry)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(
                                                    MoodColor.color(mood: entry.mood, flavour: entry.flavour),
                                                    lineWidth: selectedEntry?.id == entry.id ? 2 : 0
                                                )
                                        )
                                        .id(entry.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture { onSelect?(entry) }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                onDelete?(entry)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    if index < entries.count - 1 {
                                        Spacer(minLength: 8)
                                    }
                                }
                                Spacer(minLength: 40)
                            }
                            .frame(minHeight: proxy.size.height)
                        }
                        .onChange(of: scrollToEntry?.id) { _, newId in
                            if let newId {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollProxy.scrollTo(newId, anchor: .center)
                                }
                            }
                        }
                    }
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
        MoodEntry(id: Int64($0), mood: Double.random(in: 0...100), flavour: 0.4, note: nil, timestamp: Date())
    })
    .frame(width: 240, height: 320)
}
