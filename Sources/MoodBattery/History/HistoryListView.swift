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
                                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
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
                                        .background(GeometryReader { geo in
                                            Color.clear.preference(
                                                key: RowFrameKey.self,
                                                value: [index: geo.frame(in: .named("historyList"))]
                                            )
                                        })
                                    if index < entries.count - 1 {
                                        Spacer(minLength: 8)
                                    }
                                }
                                Spacer(minLength: 40)
                            }
                            .frame(minHeight: proxy.size.height)
                            .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
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
                }
                .mask(fadeMask)
            }
        }
    }

    // MARK: - Magnification

    @State private var rowFrames: [Int: CGRect] = [:]

    private func rowScale(for index: Int) -> CGFloat {
        guard isHovering, let cursor = hoverLocation,
              let frame = rowFrames[index] else { return 1.0 }

        let rowCenterY = frame.midY
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

private struct RowFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

#Preview {
    HistoryListView(entries: (0..<10).map {
        MoodEntry(id: Int64($0), mood: Double.random(in: 0...100), flavour: 0.4, note: nil, timestamp: Date())
    })
    .frame(width: 240, height: 320)
}
