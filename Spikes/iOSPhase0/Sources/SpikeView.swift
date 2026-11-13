import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SpikeModel: ObservableObject {
    @Published var launches = "—"
    @Published var folderPath: String?
    @Published var restoredOnLaunch = false
    @Published var files: [SyncFolder.FileReport] = []
    @Published var log: [String] = []
    @Published var isReading = false

    private var folder: SyncFolder?
    private var started = false

    /// Runs once per launch: records the launch in the database and restores the picked folder.
    func start() {
        guard !started else { return }
        started = true
        do {
            let result = try SpikeDatabase().recordLaunch()
            let since = result.first.map { " since \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
            launches = "Opened \(result.count) time(s)\(since)"
        } catch {
            note("Database: \(error.localizedDescription)")
        }
        do {
            if let restored = try SyncFolder.restore() {
                folder = restored
                folderPath = restored.url.path
                restoredOnLaunch = true
                note("Folder access restored on launch")
                refresh()
            }
        } catch {
            note("Restore folder: \(error.localizedDescription)")
        }
    }

    func picked(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let picked = try SyncFolder.remember(url)
                folder = picked
                folderPath = url.path
                restoredOnLaunch = false
                note("Folder picked")
                refresh()
            } catch {
                note("Pick: \(error.localizedDescription)")
            }
        case .failure(let error):
            note("Pick: \(error.localizedDescription)")
        }
    }

    func writeLine() {
        guard let folder else { return }
        do {
            try folder.appendOwnLine()
            note("Wrote a line to \(SyncFolder.ownFileName)")
            refresh()
        } catch {
            note("Write: \(error.localizedDescription)")
        }
    }

    /// Re-reads the folder off the main thread, since a coordinated read waits for iCloud downloads.
    func refresh() {
        guard let folder, !isReading else { return }
        isReading = true
        Task.detached {
            let result = Result { try folder.listFiles() }
            await MainActor.run {
                switch result {
                case .success(let files):
                    self.files = files
                    self.note("Read \(files.count) file(s)")
                case .failure(let error):
                    self.note("Read: \(error.localizedDescription)")
                }
                self.isReading = false
            }
        }
    }

    func note(_ message: String) {
        log.insert("\(Date().formatted(date: .omitted, time: .standard))  \(message)", at: 0)
    }
}

/// One screen covering the four Phase 0 checks; see README.md for what each should show.
struct SpikeView: View {
    @StateObject private var model = SpikeModel()
    @State private var isPicking = false

    var body: some View {
        NavigationStack {
            List {
                Section("1–2 · Install & database") {
                    Text(model.launches)
                    Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")")
                        .foregroundStyle(.secondary)
                }
                Section("3 · Sync folder") {
                    if let path = model.folderPath {
                        Text(path).font(.footnote).textSelection(.enabled)
                        Label(model.restoredOnLaunch ? "Access restored on launch"
                                                     : "Picked this launch — close and reopen to test",
                              systemImage: model.restoredOnLaunch ? "checkmark.circle" : "arrow.clockwise")
                    }
                    Button(model.folderPath == nil ? "Pick folder" : "Pick a different folder") { isPicking = true }
                }
                Section("4 · Files in the folder") {
                    Button("Write a line to \(SyncFolder.ownFileName)") { model.writeLine() }
                        .disabled(model.folderPath == nil)
                    Button(model.isReading ? "Reading…" : "Refresh") { model.refresh() }
                        .disabled(model.folderPath == nil || model.isReading)
                    ForEach(model.files) { file in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.id).font(.body.monospaced())
                            Text(file.status).font(.caption).foregroundStyle(.secondary)
                            if let count = file.lineCount { Text("\(count) line(s)").font(.caption) }
                            if let last = file.lastLine {
                                Text(last).font(.caption.monospaced()).lineLimit(2)
                            }
                        }
                    }
                }
                Section("Log") {
                    ForEach(Array(model.log.enumerated()), id: \.offset) { item in
                        Text(item.element).font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("Swing spike")
            .refreshable { model.refresh() }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.folder]) { model.picked($0) }
        .task { model.start() }
    }
}
