import SwiftUI

struct EntryDetailPanel: View {
    let entry: MoodEntry
    var onClose: () -> Void
    var onDelete: (() -> Void)?
    var onUpdate: ((MoodEntry) -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    @State private var editingField: EditField?
    @State private var draftMood: String = ""
    @State private var draftFlavour: String = ""
    @State private var draftTitle: String = ""
    @State private var draftNote: String = ""
    @FocusState private var panelFocused: Bool

    private enum EditField: Equatable { case mood, flavour, title, note }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    private var moodLabel: String {
        MoodState.label(mood: entry.mood, flavour: entry.flavour)
    }

    private var flavourLabel: String {
        if entry.flavour < 0.35 { return "calm" }
        if entry.flavour > 0.65 { return "irritable" }
        return "normal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if editingField == .note {
                content
            } else {
                ScrollView {
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(GlassPanelModifier())
        .shadow(color: .black.opacity(0.25), radius: 20, x: 4, y: 0)
        .focusable()
        .focused($panelFocused)
        .focusEffectDisabled()
        .onAppear { panelFocused = true }
        .onChange(of: entry.id) { _, _ in panelFocused = true }
        .onChange(of: editingField) { _, newField in
            if newField == nil { panelFocused = true }
        }
        .onExitCommand {
            if editingField != nil {
                editingField = nil
            } else {
                onClose()
            }
        }
        .onKeyPress(.upArrow) {
            guard editingField == nil else { return .ignored }
            onPrevious?()
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard editingField == nil else { return .ignored }
            onNext?()
            return .handled
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: entry.timestamp))
                    .font(.system(size: 13, weight: .semibold))
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(MoodColor.color(mood: entry.mood, flavour: entry.flavour))
                    .frame(width: 6, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(moodLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MoodColor.color(mood: entry.mood, flavour: entry.flavour))

                    HStack(spacing: 8) {
                        moodField
                        Text("·").foregroundStyle(.quaternary)
                        flavourField
                    }
                }
            }

            titleField

            noteField
        }
        .padding(16)
    }

    // MARK: - Editable fields

    @ViewBuilder
    private var moodField: some View {
        if editingField == .mood {
            HStack(spacing: 2) {
                Text("Mood ")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField("", text: $draftMood)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 30)
                    .onSubmit { commitMood() }
                    .onExitCommand { editingField = nil }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.tankSurface))
        } else {
            Text("Mood \(Int(entry.mood))")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .onTapGesture(count: 2) {
                    draftMood = "\(Int(entry.mood))"
                    editingField = .mood
                }
        }
    }

    @ViewBuilder
    private var flavourField: some View {
        if editingField == .flavour {
            HStack(spacing: 2) {
                Text("Flavour ")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField("", text: $draftFlavour)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 55)
                    .onSubmit { commitFlavour() }
                    .onExitCommand { editingField = nil }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.tankSurface))
        } else {
            Text("Flavour \(flavourLabel)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .onTapGesture(count: 2) {
                    draftFlavour = flavourLabel
                    editingField = .flavour
                }
        }
    }

    @ViewBuilder
    private var titleField: some View {
        let title = entry.title ?? ""
        if editingField == .title {
            TextField("Title", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.tankSurface))
                .onSubmit { commitTitle() }
                .onExitCommand { editingField = nil }
        } else if !title.isEmpty {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture(count: 2) {
                    draftTitle = title
                    editingField = .title
                }
        } else {
            Text("No title")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture(count: 2) {
                    draftTitle = ""
                    editingField = .title
                }
        }
    }

    @ViewBuilder
    private var noteField: some View {
        let note = entry.note ?? ""
        if editingField == .note {
            VStack(spacing: 8) {
                TextEditor(text: $draftNote)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.tankSurface))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Spacer()
                    Button {
                        commitNote()
                    } label: {
                        Text("Done")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .modifier(GlassButtonModifier())
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !note.isEmpty {
            Text(note)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    draftNote = note
                    editingField = .note
                }
        } else {
            Text("No note")
                .font(.system(size: 13))
                .foregroundStyle(.quaternary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture(count: 2) {
                    draftNote = ""
                    editingField = .note
                }
        }
    }

    // MARK: - Commit

    private func commitMood() {
        guard let newMood = Double(draftMood),
              (0...100).contains(newMood) else { editingField = nil; return }
        var updated = entry
        updated.mood = newMood
        onUpdate?(updated)
        editingField = nil
    }

    private func commitFlavour() {
        let input = draftFlavour.trimmingCharacters(in: .whitespaces).lowercased()
        var newFlavour: Double?
        switch input {
        case "calm": newFlavour = 0.0
        case "normal": newFlavour = 0.5
        case "irritable": newFlavour = 1.0
        default: newFlavour = Double(input)
        }
        guard let val = newFlavour, (0...1).contains(val) else { editingField = nil; return }
        var updated = entry
        updated.flavour = val
        onUpdate?(updated)
        editingField = nil
    }

    private func commitTitle() {
        var updated = entry
        updated.title = draftTitle.isEmpty ? nil : draftTitle
        onUpdate?(updated)
        editingField = nil
    }

    private func commitNote() {
        var updated = entry
        updated.note = draftNote.isEmpty ? nil : draftNote
        onUpdate?(updated)
        editingField = nil
    }
}

private struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

#Preview {
    EntryDetailPanel(
        entry: MoodEntry(id: 1, mood: 72, flavour: 0.3, title: "Great morning", note: "Had a great morning, went for a run and felt really energized.", timestamp: Date()),
        onClose: {}
    )
    .frame(height: 500)
}
