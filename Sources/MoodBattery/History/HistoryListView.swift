import SwiftUI

struct HistoryListView: View {
    let entries: [MoodEntry]
    var selectedEntry: MoodEntry?
    var onSelect: ((MoodEntry) -> Void)?
    var onDelete: ((MoodEntry) -> Void)?
    var scrollToEntry: MoodEntry?

    @State private var hoverLocation: CGPoint?
    @State private var isHovering = false

    private let maxScale: CGFloat = 1.05
    private let magnifyRadius: CGFloat = 120
    private let estimatedRowHeight: CGFloat = 54

    var body: some View {
        Group {
            if entries.isEmpty {
                Text("No entries yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(entries) { entry in
                                let index = entryIndex(entry)
                                HistoryEntryRow(entry: entry)
                                    .padding(.horizontal, 8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                MoodColor.color(mood: entry.mood, flavour: entry.flavour),
                                                lineWidth: selectedEntry?.id == entry.id ? 2 : 0
                                            )
                                            .padding(.horizontal, 8)
                                    )
                                    .scaleEffect(rowScale(for: index), anchor: .center)
                                    .animation(.easeOut(duration: 0.15), value: hoverLocation)
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
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .scrollClipDisabled()
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoverLocation = location
                            isHovering = true
                        case .ended:
                            hoverLocation = nil
                            isHovering = false
                        }
                    }
                    .onChange(of: scrollToEntry?.id) { _, newId in
                        if let newId {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollProxy.scrollTo(newId, anchor: .center)
                            }
                        }
                    }
                }
                .mask(fadeMask)
            }
        }
    }

    // MARK: - Magnification

    private func entryIndex(_ entry: MoodEntry) -> Int {
        entries.firstIndex(where: { $0.id == entry.id }) ?? 0
    }

    private func rowScale(for index: Int) -> CGFloat {
        guard isHovering, let cursor = hoverLocation else { return 1.0 }

        let rowCenterY = CGFloat(index) * estimatedRowHeight + estimatedRowHeight / 2
        let distance = abs(cursor.y - rowCenterY)

        guard distance < magnifyRadius else { return 1.0 }

        let normalized = 1.0 - (distance / magnifyRadius)
        let curve = cos((1.0 - normalized) * .pi / 2)
        return 1.0 + (maxScale - 1.0) * curve
    }

    // MARK: - Fade mask

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
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
