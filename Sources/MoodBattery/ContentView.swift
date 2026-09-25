import SwiftUI

struct ContentView: View {
    @State private var entries: [MoodEntry] = []
    @State private var selectedEntry: MoodEntry?
    @State private var showImporter = false
    @State private var pendingImportEntries: [EditableImportEntry] = []
    @State private var showImportPreview = false
    @State private var importError: String?

    private let store = MoodEntryStore()
    private let importer = MarkdownImporter()

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    MoodEntryEditor(onSave: reload)
                    WeeklyDiagramView(entries: entries)
                        .padding(.leading, 24)
                }
                HistoryListView(entries: entries, onSelect: { entry in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedEntry = entry
                    }
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24)

            if let entry = selectedEntry {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEntry = nil
                        }
                    }

                EntryDetailPanel(entry: entry, onClose: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntry = nil
                    }
                })
                .padding(16)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .onAppear(perform: reload)
        .toolbar {
            ToolbarItem {
                Button(action: { showImporter = true }) {
                    Label("Import diary", systemImage: "square.and.arrow.down")
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

    private func confirmImport() {
        for entry in pendingImportEntries {
            let mood = MoodEntry(
                id: nil,
                energy: entry.energy,
                flavour: entry.flavour,
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
