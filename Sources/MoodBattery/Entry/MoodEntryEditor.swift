import SwiftUI

extension VerticalAlignment {
    private enum GaugeBaselineTop: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.top] }
    }
    static let gaugeBaselineTop = VerticalAlignment(GaugeBaselineTop.self)
}

struct MoodEntryEditor: View {
    @State private var mood: Double = MoodScale.baseline
    @State private var flavour: Double = 0
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var saveError: String?

    var targetDate: Date?
    var onSave: (() -> Void)?

    private let store = MoodEntryStore()

    private let headerHeight: CGFloat = 56
    private let headerGaugeSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .gaugeBaselineTop, spacing: 20) {
                VStack(spacing: headerGaugeSpacing) {
                    header
                        .frame(height: headerHeight)
                    GaugeView(mood: mood, flavour: flavour, onMoodChange: { mood = $0 })
                }
                .alignmentGuide(.gaugeBaselineTop) { _ in
                    headerHeight + headerGaugeSpacing + GaugeView.baselineTopY
                }

                VStack(spacing: headerGaugeSpacing) {
                    Text(flavourLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, height: headerHeight, alignment: .bottom)

                    flavourTrack
                }
                .alignmentGuide(.gaugeBaselineTop) { _ in
                    headerHeight + headerGaugeSpacing + GaugeView.baselineTopY
                }
            }

            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .modifier(GlassFieldModifier())

            GrowingTextEditor(text: $note, placeholder: "Note")

            if let targetDate {
                Text("Logging for \(Self.dateLabel.string(from: targetDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Log entry", action: save)
                .modifier(GlassButtonModifier())

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(MoodState.label(mood: mood, flavour: flavour))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MoodScale.format(mood))
                .font(.system(size: 28, weight: .medium))
        }
    }

    private var flavourLabel: String {
        if flavour < 0.35 { return "calm" }
        if flavour > 0.65 { return "irritable" }
        return "normal"
    }

    private var flavourTrack: some View {
        let length = 160 * GaugeView.scale
        let trackWidth: CGFloat = 6
        let thumbSize: CGFloat = 18
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Color.tankSurface)
                .overlay(
                    Capsule().stroke(Color.tankBorder.opacity(0.3), lineWidth: 1)
                )
                .frame(width: trackWidth, height: length)

            Circle()
                .fill(MoodColor.color(mood: max(mood, MoodScale.baseline + 0.1), flavour: flavour))
                .overlay(Circle().stroke(Color.tankBorder, lineWidth: 1.5))
                .frame(width: thumbSize, height: thumbSize)
                .offset(y: flavour * (length - thumbSize))
        }
        .frame(width: thumbSize + 16, height: length)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let clamped = max(0, min(value.location.y, length))
                    flavour = clamped / length
                }
        )
    }

    private var entryDate: Date {
        targetDate ?? Date()
    }

    private func save() {
        do {
            if try store.hasEntry(on: entryDate) {
                saveError = "An entry already exists for this day."
                return
            }
            let entry = MoodEntry(
                id: nil,
                mood: mood,
                flavour: flavour,
                title: title.isEmpty ? nil : title,
                note: note.isEmpty ? nil : note,
                timestamp: entryDate
            )
            try store.save(entry)
            title = ""
            note = ""
            saveError = nil
            onSave?()
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private static let dateLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
}

#Preview {
    MoodEntryEditor()
}
