import SwiftUI

/// Throwaway Phase 1 harness: paste an entry's text, run the injected classifier, see the tags.
///
/// This exists only to eyeball tag quality on real entries before any persistence or UI is built on
/// top (the Phase 1 gate). Swap `KeywordClassifier` for the llama.cpp-backed classifier in
/// `ContentView` to test the real model through the same screen. Delete once Phase 2 lands.
struct TagSpikeView: View {
    let classifier: EntryClassifier
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""
    @State private var tags: [MoodTag] = []
    @State private var hasRun = false
    @State private var isRunning = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tag spike").font(.headline)
            Text("Paste a real entry and classify it. Phase 1 harness only.")
                .font(.caption).foregroundStyle(.secondary)

            TextField("Title (optional)", text: $title)
                .textFieldStyle(.roundedBorder)

            Text("Note").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $note)
                .font(.system(size: 13))
                .frame(minHeight: 140)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button(isRunning ? "Classifying…" : "Classify") { run() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(isRunning)
                Spacer()
                Button("Close") { dismiss() }
            }

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }

            if hasRun {
                Text("Tags").font(.caption).foregroundStyle(.secondary)
                if tags.isEmpty {
                    Text("— no tags —").font(.system(size: 13)).foregroundStyle(.tertiary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(tags) { tag in
                            Text(tag.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(Color.accentColor.opacity(0.22)))
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func run() {
        isRunning = true
        errorText = nil
        Task {
            do {
                let result = try await classifier.classify(
                    title: title.isEmpty ? nil : title,
                    note: note.isEmpty ? nil : note
                )
                await MainActor.run {
                    tags = result
                    hasRun = true
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }
}
