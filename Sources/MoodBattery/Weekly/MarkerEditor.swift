import SwiftUI

/// The sheet for adding or changing a diagram marker: a short label and its kind.
struct MarkerEditor: View {
    @State var marker: DiagramMarker
    var onSave: (DiagramMarker) -> Void
    var onCancel: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    private var trimmedLabel: String { marker.label.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(marker.id == nil ? "Add marker" : "Edit marker")
                    .font(.headline)
                if let day = marker.day() {
                    Text(Self.dateFormatter.string(from: day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Kind", selection: $marker.kind) {
                ForEach(DiagramMarker.Kind.allCases) { kind in
                    Label(kind.name, systemImage: kind.symbol).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField(placeholder, text: $marker.label)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(marker.id == nil ? "Add marker" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedLabel.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var placeholder: String {
        switch marker.kind {
        case .medication: "Quetiapine 150 mg"
        case .appointment: "Psychiatrist follow-up"
        case .other: "Moved flat"
        }
    }

    private func save() {
        guard !trimmedLabel.isEmpty else { return }
        var saved = marker
        saved.label = trimmedLabel
        onSave(saved)
    }
}

#Preview {
    MarkerEditor(marker: DiagramMarker(id: nil, localDate: "2026-09-11", label: "", kind: .medication),
                 onSave: { _ in }, onCancel: {})
}
