import SwiftUI

struct HistoryListView: View {
    let entries: [MoodEntry]
    var selectedEntry: MoodEntry?
    var onSelect: ((MoodEntry) -> Void)?
    var onDelete: ((MoodEntry) -> Void)?
    var scrollToEntry: MoodEntry?
    /// Shown when `entries` is empty (e.g. "No matches" while searching).
    var emptyMessage = "No entries yet"

    @State private var hoverLocation: CGPoint?
    @State private var isHovering = false

    private static let maxScale: CGFloat = 1.05
    private let magnifyRadius: CGFloat = 120
    /// Side room for a row at full magnification (half its growth) plus the outer half of the 2pt selection stroke;
    /// anything wider than the list is cut off by the fade mask.
    fileprivate static let rowInset: CGFloat = ceil(HistoryEntryRow.minimumWidth * (maxScale - 1) / 2) + 2

    /// Width of the list: every row shows all its tags and still has room to magnify.
    static var width: CGFloat { HistoryEntryRow.minimumWidth + rowInset * 2 }

    var body: some View {
        Group {
            if entries.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(entries) { entry in
                                ScaledEntryRow(
                                    entry: entry,
                                    isSelected: selectedEntry?.id == entry.id,
                                    hoverLocation: hoverLocation,
                                    isHovering: isHovering,
                                    maxScale: Self.maxScale,
                                    magnifyRadius: magnifyRadius,
                                    onSelect: { onSelect?(entry) },
                                    onDelete: { onDelete?(entry) }
                                )
                                .id(entry.id)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .scrollClipDisabled()
                    .coordinateSpace(name: "historyList")
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

private struct ScaledEntryRow: View {
    let entry: MoodEntry
    let isSelected: Bool
    let hoverLocation: CGPoint?
    let isHovering: Bool
    let maxScale: CGFloat
    let magnifyRadius: CGFloat
    var onSelect: () -> Void
    var onDelete: () -> Void

    @State private var rowMidY: CGFloat = 0

    private var scale: CGFloat {
        guard isHovering, let cursor = hoverLocation else { return 1.0 }
        let distance = abs(cursor.y - rowMidY)
        guard distance < magnifyRadius else { return 1.0 }
        let normalized = 1.0 - (distance / magnifyRadius)
        let curve = cos((1.0 - normalized) * .pi / 2)
        return 1.0 + (maxScale - 1.0) * curve
    }

    var body: some View {
        HistoryEntryRow(entry: entry)
            .padding(.horizontal, HistoryListView.rowInset)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        MoodColor.color(mood: entry.mood, flavour: entry.flavour),
                        lineWidth: isSelected ? 2 : 0
                    )
                    .padding(.horizontal, HistoryListView.rowInset)
            )
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("historyList")).midY } action: { rowMidY = $0 }
            .scaleEffect(scale, anchor: .center)
            .animation(.easeOut(duration: 0.15), value: hoverLocation)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

#Preview {
    HistoryListView(entries: (0..<10).map {
        MoodEntry(id: Int64($0), mood: Double.random(in: MoodScale.range), flavour: 0.4, note: nil, timestamp: Date())
    })
    .frame(width: 240, height: 320)
}
