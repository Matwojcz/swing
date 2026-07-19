import SwiftUI

/// Anchors the header (state label + number) to the gauge's center, and the
/// flavour slider's control to the gauge's dashed baseline tick, across the
/// HStack that lays those three pieces out side by side.
extension VerticalAlignment {
    private enum GaugeBaselineTop: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.top] }
    }
    static let gaugeBaselineTop = VerticalAlignment(GaugeBaselineTop.self)
}

/// The daily entry screen: the interactive gauge plus the flavour slider
/// that drives it, a note field, and a save action.
struct MoodEntryEditor: View {
    @State private var energy: Double = 50
    @State private var flavour: Double = 0
    @State private var note: String = ""
    @State private var saveError: String?

    var onSave: (() -> Void)?

    private let store = MoodEntryStore()

    private let headerHeight: CGFloat = 56
    private let headerGaugeSpacing: CGFloat = 8
    private let flavourLabelHeight: CGFloat = 16
    private let flavourLabelSpacing: CGFloat = 6

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .gaugeBaselineTop, spacing: 20) {
                VStack(spacing: headerGaugeSpacing) {
                    header
                        .frame(height: headerHeight)
                    GaugeView(energy: energy, flavour: flavour, onEnergyChange: { energy = $0 })
                }
                .alignmentGuide(.gaugeBaselineTop) { _ in
                    headerHeight + headerGaugeSpacing + GaugeView.baselineTopY
                }

                flavourSlider
                    .alignmentGuide(.gaugeBaselineTop) { _ in flavourLabelHeight + flavourLabelSpacing }
            }

            TextField("Note (optional)", text: $note)
                .textFieldStyle(.roundedBorder)

            Button("Log entry", action: save)
                .buttonStyle(.borderedProminent)

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
            Text(MoodState.label(energy: energy, flavour: flavour))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(energy))")
                .font(.system(size: 28, weight: .medium))
        }
    }

    private var flavourSlider: some View {
        let length = 160 * GaugeView.scale
        let thickness = 30 * GaugeView.scale
        return VStack(spacing: flavourLabelSpacing) {
            Text("happy")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: flavourLabelHeight)
            Slider(value: $flavour, in: 0...1)
                .frame(width: length)
                .rotationEffect(.degrees(90))
                .frame(width: thickness, height: length)
            Text("irritable")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        let entry = MoodEntry(
            id: nil,
            energy: energy,
            flavour: flavour,
            note: note.isEmpty ? nil : note,
            timestamp: Date()
        )
        do {
            try store.save(entry)
            note = ""
            saveError = nil
            onSave?()
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

#Preview {
    MoodEntryEditor()
}
