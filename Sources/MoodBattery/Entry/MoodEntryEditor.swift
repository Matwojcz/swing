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
    /// Called with the composed entry when the user taps "Log entry". Return nil on success or a user-facing error string to display. Persistence and duplicate-day validation live in the parent.
    var onSaveRequest: ((MoodEntry) -> String?)?
    /// Fired after a successful save so the parent can refresh state and clear the retro-date, etc.
    var onSave: (() -> Void)?
    /// When set, the gauge and flavour track display this entry's values in read-only mode instead of the editor draft.
    var previewEntry: MoodEntry?
    /// Enlarges the gauge and flavour slider together (1 = design size); the parent caps it.
    var gaugeZoom: CGFloat = 1

    @State private var gaugeRowSize: CGSize = .zero

    private let headerHeight: CGFloat = Self.headerHeight
    private let headerGaugeSpacing: CGFloat = Self.headerGaugeSpacing
    private static let headerHeight: CGFloat = 56
    private static let headerGaugeSpacing: CGFloat = 8
    private static let gaugeSliderSpacing: CGFloat = 20
    private static let flavourTrackWidth: CGFloat = 18 + 16
    static let padding: CGFloat = 24

    /// Footprint of the gauge row (readout, dial and flavour slider) at zoom 1, for the parent's zoom calculation.
    static let gaugeRowDesignSize = CGSize(
        width: GaugeView.width + gaugeSliderSpacing + flavourTrackWidth,
        height: headerHeight + headerGaugeSpacing + GaugeView.height
    )

    /// Whether the editor is currently showing a read-only preview of an existing entry.
    private var isPreviewing: Bool { previewEntry != nil }
    /// The mood value to display on the gauge — the preview entry's value when previewing, otherwise the editor draft.
    private var displayMood: Double { previewEntry?.mood ?? mood }
    /// The flavour value to display — the preview entry's value when previewing, otherwise the editor draft.
    private var displayFlavour: Double { previewEntry?.flavour ?? flavour }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .gaugeBaselineTop, spacing: Self.gaugeSliderSpacing) {
                VStack(spacing: headerGaugeSpacing) {
                    header
                        .frame(height: headerHeight)
                    GaugeView(mood: displayMood, flavour: displayFlavour,
                              onMoodChange: isPreviewing ? nil : { mood = $0 })
                }
                .alignmentGuide(.gaugeBaselineTop) { _ in
                    headerHeight + headerGaugeSpacing + GaugeView.baselineTopY
                }

                VStack(spacing: headerGaugeSpacing) {
                    VStack(spacing: 2) {
                        Text(flavourLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", displayFlavour))
                            .font(.system(size: 15, weight: .medium))
                            .monospacedDigit()
                    }
                    .frame(width: 50, height: headerHeight, alignment: .bottom)

                    flavourTrack
                }
                .alignmentGuide(.gaugeBaselineTop) { _ in
                    headerHeight + headerGaugeSpacing + GaugeView.baselineTopY
                }
            }
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { gaugeRowSize = $0 }
            // Scaling as a render transform keeps the drawing and drag maths at design size;
            // the frame reserves the enlarged footprint so the fields below move down with it.
            .scaleEffect(gaugeZoom, anchor: .top)
            .frame(width: gaugeRowSize == .zero ? nil : gaugeRowSize.width * gaugeZoom,
                   height: gaugeRowSize == .zero ? nil : gaugeRowSize.height * gaugeZoom,
                   alignment: .top)

            if !isPreviewing {
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
        }
        .padding(Self.padding)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(MoodState.label(mood: displayMood, flavour: displayFlavour))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(MoodScale.format(displayMood))
                .font(.system(size: 28, weight: .medium))
        }
    }

    private var flavourLabel: String {
        MoodScale.flavourLabel(displayFlavour)
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
                .fill(MoodColor.color(mood: max(displayMood, MoodScale.baseline + 0.1), flavour: displayFlavour))
                .overlay(Circle().stroke(Color.tankBorder, lineWidth: 1.5))
                .frame(width: thumbSize, height: thumbSize)
                .offset(y: displayFlavour * (length - thumbSize))
        }
        .frame(width: Self.flavourTrackWidth, height: length)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !isPreviewing else { return }
                    let clamped = max(0, min(value.location.y, length))
                    flavour = clamped / length
                }
        )
    }

    private var entryDate: Date {
        targetDate ?? Date()
    }

    /// Builds the entry from the current form and asks the parent to persist it; on success clears the form and notifies the parent.
    private func save() {
        let entry = MoodEntry(
            id: nil,
            mood: mood,
            flavour: flavour,
            title: title.isEmpty ? nil : title,
            note: note.isEmpty ? nil : note,
            timestamp: entryDate
        )
        if let error = onSaveRequest?(entry) {
            saveError = error
        } else {
            title = ""
            note = ""
            saveError = nil
            onSave?()
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
