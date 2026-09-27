import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var entries: [MoodEntry] = []
    @State private var selectedEntry: MoodEntry?
    @State private var scrollToEntry: MoodEntry?
    @State private var showImporter = false
    @State private var pendingImportEntries: [EditableImportEntry] = []
    @State private var showImportPreview = false
    @State private var importError: String?
    @State private var showClearConfirmation = false
    @State private var retroDate: Date?
    @State private var diagramScrollDate: Date?

    private let store = MoodEntryStore()
    private let importer = MarkdownImporter()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                VStack(alignment: .leading, spacing: 24) {
                    MoodEntryEditor(targetDate: retroDate, onSave: {
                        retroDate = nil
                        reload()
                    })
                    MoodDiagramView(entries: entries, onSelectDate: { date in
                        let cal = Calendar.current
                        if let entry = entries.first(where: { cal.isDate($0.timestamp, inSameDayAs: date) }) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedEntry = entry
                                scrollToEntry = entry
                                diagramScrollDate = entry.timestamp
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                retroDate = date
                            }
                        }
                    }, scrollToDate: diagramScrollDate)
                    .padding(.horizontal, 16)
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
                    }, onUpdate: { updated in
                        try? store.save(updated)
                        reload()
                        selectedEntry = updated
                    }, onPrevious: {
                        navigateEntry(direction: -1)
                    }, onNext: {
                        navigateEntry(direction: 1)
                    })
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HistoryListView(
                entries: entries,
                selectedEntry: selectedEntry,
                onSelect: { entry in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedEntry = entry
                        diagramScrollDate = entry.timestamp
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
            .frame(maxHeight: .infinity)
            .frame(width: 280)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .onAppear(perform: reload)
        .toolbar {
            ToolbarItem {
                Button(action: { showImporter = true }) {
                    Label("Import diary", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem {
                Menu {
                    Button("Export as CSV") { exportCSV() }
                    Button("Export as JSON") { exportJSON() }
                    Divider()
                    Button("Seed 6 months of dummy data") { seedDummyData() }
                    Button("Clear all entries", role: .destructive) { showClearConfirmation = true }
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
        .alert("Delete all entries?", isPresented: $showClearConfirmation) {
            Button("Delete all", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all mood entries. This cannot be undone.")
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

        var mood = 50.0
        for dayOffset in (0..<180).reversed() {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let drift = Double.random(in: -12...12, using: &rng)
            mood = max(5, min(95, mood + drift))
            let flavour = Double.random(in: 0...1, using: &rng)

            let titles = ["solid day", "rough morning", "high energy", "calm afternoon",
                          "restless night", "good focus", "tired", "creative burst",
                          "low and slow", "baseline", "wired", "quiet day"]
            let title = titles.randomElement()!

            let entry = MoodEntry(
                id: nil, mood: mood, flavour: flavour,
                title: title, note: nil, timestamp: date
            )
            try? store.save(entry)
        }
        reload()
    }

    private func navigateEntry(direction: Int) {
        guard let current = selectedEntry,
              let idx = entries.firstIndex(where: { $0.id == current.id }) else { return }
        let newIdx = idx + direction
        guard entries.indices.contains(newIdx) else { return }
        let next = entries[newIdx]
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedEntry = next
            scrollToEntry = next
            diagramScrollDate = next.timestamp
        }
    }

    private func clearAllData() {
        try? store.deleteAll()
        reload()
    }

    private func exportCSV() {
        let header = "id,mood,flavour,title,note,timestamp"
        let rows = entries.map { e in
            let fields: [String] = [
                e.id.map(String.init) ?? "",
                String(e.mood),
                String(e.flavour),
                csvEscape(e.title ?? ""),
                csvEscape(e.note ?? ""),
                Self.iso8601Formatter.string(from: e.timestamp)
            ]
            return fields.joined(separator: ",")
        }
        let csv = ([header] + rows).joined(separator: "\n")
        saveFile(content: csv, defaultName: "mood-battery-export.csv", contentType: .commaSeparatedText)
    }

    private func exportJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries),
              let json = String(data: data, encoding: .utf8) else { return }
        saveFile(content: json, defaultName: "mood-battery-export.json", contentType: .json)
    }

    private func saveFile(content: String, defaultName: String, contentType: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func confirmImport() {
        for entry in pendingImportEntries {
            let mood = MoodEntry(
                id: nil,
                mood: entry.mood,
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
