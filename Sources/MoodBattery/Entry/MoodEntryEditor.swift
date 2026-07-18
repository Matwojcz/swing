import SwiftUI

/// The daily entry screen: the interactive tank plus the two sliders that
/// drive it, a note field, and a save action.
struct MoodEntryEditor: View {
    @State private var energy: Double = 50
    @State private var flavour: Double = 0
    @State private var note: String = ""
    @State private var saveError: String?

    var onSave: (() -> Void)?

    private let store = MoodEntryStore()

    var body: some View {
        VStack(spacing: 20) {
            header

            HStack(alignment: .center, spacing: 20) {
                TankView(energy: energy, flavour: flavour)
                flavourSlider
            }
            .frame(height: 220)

            energySlider

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
        VStack(spacing: 6) {
            Text("happy")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Slider(value: $flavour, in: 0...1)
                .frame(width: 160)
                .rotationEffect(.degrees(90))
                .frame(width: 30, height: 160)
            Text("irritable")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var energySlider: some View {
        VStack(spacing: 4) {
            Slider(value: $energy, in: 0...100, step: 1)
            HStack {
                Text("depressive")
                Spacer()
                Text("baseline")
                Spacer()
                Text("hype")
            }
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
