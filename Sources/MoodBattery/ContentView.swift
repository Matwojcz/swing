import SwiftUI

struct ContentView: View {
    @State private var entries: [MoodEntry] = []
    @State private var selectedEntry: MoodEntry?
    @State private var scrollToEntry: MoodEntry?
    @State private var showImporter = false
    @State private var pendingImportEntries: [EditableImportEntry] = []
    @State private var showImportPreview = false
    @State private var importError: String?

    private let store = MoodEntryStore()
    private let importer = MarkdownImporter()

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            ZStack {
                VStack(alignment: .leading, spacing: 24) {
                    MoodEntryEditor(onSave: reload)
                    MoodDiagramView(entries: entries, onSelectDate: { date in
                        let cal = Calendar.current
                        if let entry = entries.first(where: { cal.isDate($0.timestamp, inSameDayAs: date) }) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedEntry = entry
                                scrollToEntry = entry
                            }
                        }
                    })
                    .padding(.horizontal, 24)
                }

                if let entry = selectedEntry {
                    Color.black.opacity(0.15)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedEntry = nil
                            }
                        }

                    EntryDetailPanel(entry: entry, onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEntry = nil
                        }
                    }, onDelete: {
                        try? store.delete(entry)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEntry = nil
                        }
                        reload()
                    })
                    .transition(.opacity)
                }
            }

            HistoryListView(
                entries: entries,
                selectedEntry: selectedEntry,
                onSelect: { entry in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedEntry = entry
                    }
                },
                onDelete: { entry in
                    try? store.delete(entry)
                    if selectedEntry?.id == entry.id {
                        selectedEntry = nil
                    }
                    reload()
                },
                scrollToEntry: scrollToEntry
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .onAppear(perform: reload)
        .toolbar {
            ToolbarItem {
                Button(action: { showImporter = true }) {
                    Label("Import diary", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem {
                Menu {
                    Button("Seed 6 months of dummy data") { seedDummyData() }
                    Button("Clear all entries", role: .destructive) { clearAllData() }
                } label: {
                    Label("Data", systemImage: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showImportPreview) {
            ImportPreviewSheet(
                entries: $pendingImportEntries,
                onConfirm: confirmImport,
                onCancel: { showImportPreview = false }
            )
        }
        .alert("Import error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func reload() {
        entries = (try? store.fetchAll()) ?? []
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var parsed: [MarkdownImporter.ParsedEntry] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    parsed.append(contentsOf: importer.parse(content))
                }
            }
            if parsed.isEmpty {
                importError = "No diary entries with dates found."
            } else {
                pendingImportEntries = parsed.map { EditableImportEntry(parsed: $0) }
                showImportPreview = true
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func seedDummyData() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var rng = SystemRandomNumberGenerator()

        var energy = 50.0
        for dayOffset in (0..<180).reversed() {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let drift = Double.random(in: -12...12, using: &rng)
            energy = max(5, min(95, energy + drift))
            let flavour = Double.random(in: 0...1, using: &rng)

            let titles = ["solid day", "rough morning", "high energy", "calm afternoon",
                          "restless night", "good focus", "tired", "creative burst",
                          "low and slow", "baseline", "wired", "quiet day"]
            let title = titles.randomElement()!

            let entry = MoodEntry(
                id: nil, energy: energy, flavour: flavour,
                title: title, note: nil, timestamp: date
            )
            try? store.save(entry)
        }
        reload()
    }

    private func clearAllData() {
        try? store.deleteAll()
        reload()
    }

    private func confirmImport() {
        for entry in pendingImportEntries {
            let mood = MoodEntry(
                id: nil,
                energy: entry.energy,
                flavour: entry.flavour,
                title: entry.title.isEmpty ? nil : entry.title,
                note: entry.note.isEmpty ? nil : entry.note,
                timestamp: entry.timestamp
            )
            try? store.save(mood)
        }
        showImportPreview = false
        pendingImportEntries = []
        reload()
    }
}

#Preview {
    ContentView()
}
