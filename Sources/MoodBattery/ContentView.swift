import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var entries: [MoodEntry] = []
    @State private var selectedEntry: MoodEntry?
    @State private var isDetailPanelShown = false
    @State private var scrollToEntry: MoodEntry?
    @State private var showImporter = false
    /// What the file picker is importing: picked from the Import menu.
    @State private var importFormat: ImportFormat = .markdown
    /// Rows in an imported CSV or JSON that couldn't be read, reported once the import is saved.
    @State private var unreadableImportRows = 0
    @State private var pendingImportEntries: [EditableImportEntry] = []
    @State private var showImportPreview = false
    @State private var importError: String?
    /// Shown after an import that skipped days already in the diary.
    @State private var importNotice: String?
    /// Shown when a database write or an export fails, so a lost edit doesn't pass for a saved one.
    @State private var saveError: String?
    /// Shown when the diary, or part of it, can't be read, so a failed load doesn't pass for an empty diary.
    @State private var loadError: String?
    /// Entries left out by the last load because they couldn't be read; the alert shows when this changes.
    @State private var unreadableCount = 0
    @State private var showClearConfirmation = false
    @State private var retroDate: Date?
    @State private var diagramScrollDate: Date?
    @State private var searchText = ""
    @State private var searchMatches: [MoodEntry] = []
    let tagging: TaggingController
    @State private var showAutoTagAllConfirmation = false
    @State private var cycle = CycleCalendar.empty
    /// Search matches mood band names in the words of this lens.
    @AppStorage(Lens.storageKey) private var lens: Lens = .none
    @State private var mainAreaSize: CGSize = .zero
    @State private var gaugeZoom: CGFloat = 1
    /// Height of everything in the main column except the gauge row, measured while the entry fields are showing
    /// (the tallest layout), so the gauge keeps one size whether or not an entry is selected.
    @State private var columnHeightWithoutGauge: CGFloat?
    @FocusState private var mainFocused: Bool
    /// True while a field in the detail panel is being edited, so Escape ends the edit before it closes the panel.
    @State private var isEditingInPanel = false

    /// The gauge-and-diagram column stops widening here; extra window width becomes margin around it.
    private static let maxMainColumnWidth: CGFloat = 880
    private static let maxGaugeZoom: CGFloat = 1.4
    /// Space kept free above and below the column so it never touches the window edges.
    private static let verticalBreathingRoom: CGFloat = 32

    private let store = MoodEntryStore()
    private let periodStore = PeriodStore()
    private let importer = MarkdownImporter()

    private var searchTerms: [EntrySearch.Term] { EntrySearch.terms(in: searchText, lens: lens) }
    private var isSearching: Bool { !searchTerms.isEmpty }
    /// The entries the list and keyboard navigation work on: the search matches while searching, otherwise everything.
    private var visibleEntries: [MoodEntry] { isSearching ? searchMatches : entries }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                VStack(spacing: 24) {
                    MoodEntryEditor(targetDate: retroDate, onSaveRequest: { entry in
                        do {
                            if try store.hasEntry(on: entry.timestamp) {
                                return "An entry already exists for this day."
                            }
                            try store.save(entry)
                            return nil
                        } catch {
                            return "Couldn't save: \(error.localizedDescription)"
                        }
                    }, onSave: {
                        retroDate = nil
                        reload()
                    }, onCancelTargetDate: { retroDate = nil }, previewEntry: selectedEntry, gaugeZoom: gaugeZoom,
                    onPeriodStartChange: setPeriodStart)
                    MoodDiagramView(entries: entries, onSelectDate: { date in
                        let cal = Calendar.current
                        let day = cal.startOfDay(for: date)
                        // Prefer a matching entry when searching, so tapping a marked day opens the diary that matched.
                        let tapped = visibleEntries.first(where: { $0.day(in: cal) == day })
                            ?? entries.first(where: { $0.day(in: cal) == day })
                        if let entry = tapped {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedEntry = entry
                                isDetailPanelShown = true
                                scrollToEntry = entry
                                diagramScrollDate = entry.timestamp
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                retroDate = date
                                selectedEntry = nil
                                isDetailPanelShown = false
                            }
                        }
                    }, scrollToDate: diagramScrollDate, highlightedEntry: selectedEntry,
                    searchMatches: isSearching ? searchMatches : nil)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: Self.maxMainColumnWidth)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    guard selectedEntry == nil else { return }
                    columnHeightWithoutGauge = height - MoodEntryEditor.gaugeRowDesignSize.height * gaugeZoom
                    updateGaugeZoom()
                }

                if let entry = selectedEntry, isDetailPanelShown {
                    Color.black.opacity(0.15)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture {
                            closeDetailPanel()
                        }

                    EntryDetailPanel(entry: entry, highlightTerms: searchTerms, onClose: {
                        closeDetailPanel()
                    }, onDelete: {
                        guard persist({ try store.delete(entry) }) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedEntry = nil
                            isDetailPanelShown = false
                        }
                        mainFocused = true
                        reload()
                    }, onUpdate: { updated in
                        persist({ try store.update(updated, from: entry) })
                        reload()
                    }, onPrevious: {
                        navigateEntry(direction: -1)
                    }, onNext: {
                        navigateEntry(direction: 1)
                    }, onAutoTag: {
                        tagging.autoTag(entry, onTagged: applyTagged)
                    }, isAutoTagging: tagging.activity == .single(entryID: entry.id ?? -1),
                    autoTagDisabled: tagging.isBusy, onPeriodStartChange: setPeriodStart,
                    isEditing: $isEditingInPanel)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                mainAreaSize = size
                updateGaugeZoom()
            }

            VStack(spacing: 8) {
            if isSearching {
                Text(searchMatches.count == 1 ? "1 matching entry" : "\(searchMatches.count) matching entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HistoryListView(
                entries: visibleEntries,
                selectedEntry: selectedEntry,
                onSelect: { entry in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedEntry = entry
                        isDetailPanelShown = true
                        diagramScrollDate = entry.timestamp
                    }
                },
                onDelete: { entry in
                    guard persist({ try store.delete(entry) }) else { return }
                    if selectedEntry?.id == entry.id {
                        selectedEntry = nil
                        isDetailPanelShown = false
                    }
                    reload()
                },
                scrollToEntry: scrollToEntry,
                emptyMessage: emptyListMessage,
                searchTerms: searchTerms
            )
            .frame(maxHeight: .infinity)
            }
            .frame(width: HistoryListView.width)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .focusable()
        .focused($mainFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) {
            guard !isDetailPanelShown else { return .ignored }
            navigateEntry(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !isDetailPanelShown else { return .ignored }
            navigateEntry(direction: 1)
            return .handled
        }
        .onKeyPress(.return) {
            guard !isDetailPanelShown, selectedEntry != nil else { return .ignored }
            withAnimation(.easeInOut(duration: 0.25)) {
                isDetailPanelShown = true
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if isEditingInPanel {
                isEditingInPanel = false
                return .handled
            }
            if isDetailPanelShown {
                closeDetailPanel()
                return .handled
            }
            if selectedEntry != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedEntry = nil
                }
                return .handled
            }
            if retroDate != nil {
                retroDate = nil
                return .handled
            }
            return .ignored
        }
        .environment(\.cycleCalendar, cycle)
        .onAppear {
            reload()
            mainFocused = true
        }
        // Entries can be written from outside while the app is open (the MCP server), so read them again on return.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            reload()
            // The app can stay open for days: take the day's backup when it's next used.
            DatabaseManager.shared.backUpIfDue()
        }
        .searchable(text: $searchText, prompt: "Tags and moods, or \"words\" in notes")
        .onChange(of: searchText) { runSearch() }
        .onChange(of: lens) { runSearch() }
        .onSubmit(of: .search) {
            // Return in the search field jumps to the newest match.
            guard let first = searchMatches.first else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedEntry = first
                scrollToEntry = first
                diagramScrollDate = first.timestamp
            }
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    ForEach(ImportFormat.allCases) { format in
                        Button(format.menuTitle) {
                            importFormat = format
                            showImporter = true
                        }
                    }
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import entries: a Markdown diary, or a CSV or JSON file exported from Swing")
            }
            ToolbarItem {
                Button(action: { showAutoTagAllConfirmation = true }) {
                    Label("Auto-tag all entries", systemImage: "sparkles")
                }
                .help("Tag every entry with the on-device model")
                .disabled(tagging.isBusy || entries.isEmpty)
            }
            ToolbarItem {
                Menu {
                    Button("Export as CSV") { exportCSV() }
                    Button("Export as JSON") { exportJSON() }
                    Button("Show backups in Finder") { showBackups(in: DatabaseManager.shared.backupDirectory) }
                    Button("Show iCloud backups in Finder") { showBackups(in: DatabaseManager.shared.iCloudBackupDirectory) }
                    Divider()
                    #if DEBUG
                    Button("Seed 6 months of dummy data") { seedDummyData() }
                    #endif
                    Button("Clear all entries", role: .destructive) { showClearConfirmation = true }
                } label: {
                    Label("Data", systemImage: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: importFormat.contentTypes,
            allowsMultipleSelection: importFormat == .markdown
        ) { result in
            handleFileImport(result)
        }
        .overlay(alignment: .bottom) {
            if tagging.isBusy {
                TaggingProgressCard(controller: tagging)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tagging.isBusy)
        .alert("Auto-tag your entries?", isPresented: $showAutoTagAllConfirmation) {
            let untagged = entries.filter { !TaggingController.isTagged($0) }
            let retaggable = entries.filter { !$0.hasManualTags }
            if !untagged.isEmpty {
                Button(untagged.count == retaggable.count ? "Tag all \(retaggable.count)" : "Tag \(untagged.count) untagged") {
                    tagging.autoTagAll(untagged, onTagged: applyTagged)
                }
            }
            if untagged.count < retaggable.count {
                Button("Re-tag all \(retaggable.count)") {
                    tagging.autoTagAll(retaggable, onTagged: applyTagged)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(autoTagAllMessage)
        }
        .alert("Auto-tag", isPresented: Binding(
            get: { tagging.errorMessage != nil },
            set: { if !$0 { tagging.errorMessage = nil } }
        )) {
            Button("OK") { tagging.errorMessage = nil }
        } message: {
            Text(tagging.errorMessage ?? "")
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
        .alert("Import", isPresented: Binding(
            get: { importNotice != nil },
            set: { if !$0 { importNotice = nil } }
        )) {
            Button("OK") { importNotice = nil }
        } message: {
            Text(importNotice ?? "")
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .alert("Couldn't load your diary", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
        .alert("Delete all entries?", isPresented: $showClearConfirmation) {
            Button("Delete all", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all mood entries. This cannot be undone.")
        }
    }

    /// Refreshes the entries array from the database, and the selected entry with it: it may have been changed or
    /// deleted outside the app. A failed read keeps what was loaded and says so.
    private func reload() {
        do {
            entries = try store.fetchAll()
            unreadableCount = 0
        } catch {
            // One unreadable row mustn't hide the rest: show what can be read and say what was left out.
            guard let partial = try? store.fetchReadable() else {
                loadError = "\(error.localizedDescription)\n\nYour entries are still in the database."
                return
            }
            entries = partial.entries
            if partial.unreadable != unreadableCount {
                unreadableCount = partial.unreadable
                loadError = "\(partial.unreadable) \(partial.unreadable == 1 ? "entry" : "entries") couldn't be read and "
                    + "\(partial.unreadable == 1 ? "is" : "are") left out. The rest of your diary is shown, and nothing was deleted."
            }
        }
        if let selected = selectedEntry {
            selectedEntry = entries.first { $0.id == selected.id }
            if selectedEntry == nil { isDetailPanelShown = false }
        }
        reloadCycle()
    }

    /// Reloads the period start days, then the search, whose PMDD band names depend on them.
    private func reloadCycle() {
        cycle = CycleCalendar(localDates: (try? periodStore.fetchStarts()) ?? [])
        runSearch()
    }

    private func setPeriodStart(_ day: Date, _ isStart: Bool) {
        persist { try periodStore.setStart(MoodEntry.localDateString(for: day), isStart: isStart) }
        reloadCycle()
    }

    /// Runs a database write, showing the error instead of failing silently. Returns whether it succeeded.
    @discardableResult
    private func persist(_ write: () throws -> Void) -> Bool {
        do {
            try write()
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    /// Grows the gauge into whatever room the column leaves, limited by both height and width and capped at
    /// `maxGaugeZoom`; never shrinks it below design size.
    private func updateGaugeZoom() {
        guard let rest = columnHeightWithoutGauge, mainAreaSize != .zero else { return }
        let design = MoodEntryEditor.gaugeRowDesignSize
        let byHeight = (mainAreaSize.height - Self.verticalBreathingRoom - rest) / design.height
        let columnWidth = min(mainAreaSize.width, Self.maxMainColumnWidth) - MoodEntryEditor.padding * 2
        let byWidth = columnWidth / design.width
        let zoom = min(max(min(byHeight, byWidth), 1), Self.maxGaugeZoom)
        if abs(zoom - gaugeZoom) > 0.01 { gaugeZoom = zoom }
    }

    /// Swaps a freshly tagged entry into the list, search results and open panel without reloading everything.
    private func applyTagged(_ tagged: MoodEntry) {
        if let i = entries.firstIndex(where: { $0.id == tagged.id }) { entries[i] = tagged }
        runSearch()
        if selectedEntry?.id == tagged.id { selectedEntry = tagged }
    }

    /// Explains the cost of a full pass before it starts, using the measured time per entry.
    private var autoTagAllMessage: String {
        let untagged = entries.filter { !TaggingController.isTagged($0) }.count
        let retaggable = entries.filter { !$0.hasManualTags }.count
        let manual = entries.count - retaggable
        guard retaggable > 0 else { return "Every entry has tags you picked by hand, so there's nothing to auto-tag." }
        let time = { (count: Int) in TaggingProgressCard.durationText(Double(count) * TaggingController.estimatedSecondsPerEntry) }
        let estimate = untagged == retaggable || untagged == 0
            ? "Tagging \(retaggable) entries takes \(time(retaggable))."
            : "Tagging the \(untagged) untagged entries takes \(time(untagged)); re-tagging all \(retaggable) takes \(time(retaggable))."
        let kept = manual == 0 ? ""
            : manual == 1 ? " The entry whose tags you picked by hand is left as it is."
            : " The \(manual) entries whose tags you picked by hand are left as they are."
        return "Swing reads each entry with the on-device model, so nothing leaves this Mac. \(estimate)\(kept) "
            + "You can keep using the app while it runs and cancel at any time."
    }

    /// What the empty list says. A search without quote marks only looks at tags and moods, so it points to them.
    private var emptyListMessage: String {
        guard isSearching else { return "No entries yet" }
        return searchTerms.contains(where: \.isQuoted) ? "No matches" : "No matching tags or moods. Use \"quotes\" to search your notes."
    }

    /// Filters the entries for the current search text (clearing the matches when not searching): tags and the day's
    /// band names in the current lens, or quoted words in the title or note.
    private func runSearch() {
        let terms = searchTerms
        searchMatches = terms.isEmpty ? [] : entries.filter { entry in
            let names = MoodState.searchNames(mood: entry.mood, lens: lens, cycle: cycle.position(of: entry.day()))
            return EntrySearch.matches(entry, terms: terms, names: names)
        }
    }

    /// Reads the picked files in the chosen format and opens the review sheet.
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var imported: [EditableImportEntry] = []
            var unreadable = 0
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    switch importFormat {
                    case .markdown:
                        let content = try String(contentsOf: url, encoding: .utf8)
                        imported += importer.parse(content).map { EditableImportEntry(parsed: $0) }
                    case .csv:
                        let read = try ExportFileImporter.entries(fromCSV: String(contentsOf: url, encoding: .utf8))
                        imported += read.entries.map { EditableImportEntry(entry: $0) }
                        unreadable += read.skipped
                    case .json:
                        let read = try ExportFileImporter.entries(fromJSON: Data(contentsOf: url))
                        imported += read.entries.map { EditableImportEntry(entry: $0) }
                        unreadable += read.skipped
                    }
                } catch {
                    importError = error.localizedDescription
                    return
                }
            }
            if imported.isEmpty {
                importError = importFormat == .markdown ? "No diary entries with dates found."
                    : "No entries could be read from this file."
            } else {
                pendingImportEntries = imported
                unreadableImportRows = unreadable
                showImportPreview = true
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    #if DEBUG
    /// Generates 6 months of random-walk mood entries for development and testing, skipping days that already have one.
    /// Debug builds only: in the app it would mix fake days into the real diary.
    private func seedDummyData() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var rng = SystemRandomNumberGenerator()

        var mood = MoodScale.baseline
        for dayOffset in (0..<180).reversed() {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let drift = Double.random(in: -1.2...1.2, using: &rng)
            mood = max(0.5, min(9.5, mood + drift))
            mood = (mood / MoodScale.step).rounded() * MoodScale.step
            let flavour = Double.random(in: 0...1, using: &rng)

            let titles = ["solid day", "rough morning", "high energy", "calm afternoon",
                          "restless night", "good focus", "tired", "creative burst",
                          "low and slow", "baseline", "wired", "quiet day"]
            let title = titles.randomElement()!

            let entry = MoodEntry(
                id: nil, mood: mood, flavour: flavour,
                title: title, note: nil, timestamp: date
            )
            if (try? store.hasEntry(on: date)) == false {
                _ = try? store.save(entry)
            }
        }
        reload()
    }
    #endif

    /// Moves the selection to the previous (-1) or next (+1) entry in the list; selects the first entry if none is selected yet.
    private func navigateEntry(direction: Int) {
        let list = visibleEntries
        guard !list.isEmpty else { return }
        let next: MoodEntry
        if let current = selectedEntry,
           let idx = list.firstIndex(where: { $0.id == current.id }) {
            let newIdx = idx + direction
            guard list.indices.contains(newIdx) else { return }
            next = list[newIdx]
        } else {
            next = list[0]
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedEntry = next
            scrollToEntry = next
            diagramScrollDate = next.timestamp
        }
    }

    /// Closes the detail panel while keeping the entry highlighted so the gauge continues to show its values, and returns focus to the main view.
    private func closeDetailPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDetailPanelShown = false
        }
        mainFocused = true
    }

    /// Wipes all mood entries from the database and refreshes the view, which also closes the open entry.
    private func clearAllData() {
        tagging.cancelBatch()
        persist { try store.deleteAll() }
        reload()
    }

    /// Opens a folder of database backups, or says why it can't.
    private func showBackups(in directory: URL?) {
        guard let directory, FileManager.default.fileExists(atPath: directory.path) else {
            saveError = "The backup folder \(directory?.path ?? "") doesn't exist."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    /// Serialises all entries as CSV and presents a save dialog.
    private func exportCSV() {
        let csv = ExportService.csv(from: entries)
        saveFile(content: csv, defaultName: "mood-battery-export.csv", contentType: .commaSeparatedText)
    }

    /// Serialises all entries as JSON and presents a save dialog.
    private func exportJSON() {
        do {
            let json = try ExportService.json(from: entries)
            saveFile(content: json, defaultName: "mood-battery-export.json", contentType: .json)
        } catch {
            saveError = "The export wasn't written: \(error.localizedDescription)"
        }
    }

    /// Opens an NSSavePanel and writes the given content to the user-chosen location.
    private func saveFile(content: String, defaultName: String, contentType: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            saveError = "The export wasn't written: \(error.localizedDescription)"
        }
    }

    /// Saves the reviewed import entries and closes the preview sheet. Days that already have an entry are skipped,
    /// as the editor does, so re-importing a diary can't create duplicate days.
    private func confirmImport() {
        var skipped = 0
        for entry in pendingImportEntries {
            let mood = entry.moodEntry
            let saved = persist {
                // By the entry's own day, which an export records even if the time zone has changed since.
                if try store.hasEntry(on: mood.day()) {
                    skipped += 1
                } else {
                    try store.save(mood)
                }
            }
            if !saved { break }
        }
        showImportPreview = false
        pendingImportEntries = []
        reload()
        var notes: [String] = []
        if skipped > 0 {
            notes.append("Skipped \(skipped) \(skipped == 1 ? "entry" : "entries") for days that already have one.")
        }
        if unreadableImportRows > 0 {
            notes.append("\(unreadableImportRows) \(unreadableImportRows == 1 ? "row" : "rows") in the file couldn't be read "
                + "(a missing or out-of-range mood, flavour or date) and \(unreadableImportRows == 1 ? "was" : "were") left out.")
        }
        unreadableImportRows = 0
        if !notes.isEmpty { importNotice = notes.joined(separator: " ") }
    }
}

/// The files the Import menu can read.
enum ImportFormat: String, CaseIterable, Identifiable {
    case markdown, csv, json

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .markdown: "Import Markdown diary (.md)…"
        case .csv: "Import CSV (.csv)…"
        case .json: "Import JSON (.json)…"
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .markdown: [.plainText]
        case .csv: [.commaSeparatedText]
        case .json: [.json]
        }
    }
}

#Preview {
    ContentView(tagging: TaggingController())
}
