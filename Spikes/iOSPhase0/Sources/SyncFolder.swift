import Foundation

enum SpikeError: LocalizedError {
    case noAccess
    var errorDescription: String? { "No permission to use that folder" }
}

/// Checks 3–4: a folder picked once in the Files picker (e.g. iCloud Drive/Swing/sync-spike), kept across
/// launches with a bookmark; this device appends to its own file there, and reads every file in the folder —
/// including ones iCloud hasn't downloaded to the phone yet — the way the real sync will.
final class SyncFolder: @unchecked Sendable {
    static let bookmarkKey = "syncFolderBookmark"
    static let ownFileName = "iphone-spike.jsonl"

    let url: URL

    private init(url: URL) { self.url = url }

    /// Saves a bookmark for a folder just picked in the Files picker.
    static func remember(_ url: URL) throws -> SyncFolder {
        guard url.startAccessingSecurityScopedResource() else { throw SpikeError.noAccess }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        return SyncFolder(url: url)
    }

    /// Restores the folder picked on an earlier launch, or nil if none was picked. Refreshes a stale bookmark.
    static func restore() throws -> SyncFolder? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        guard url.startAccessingSecurityScopedResource() else { throw SpikeError.noAccess }
        if isStale {
            let fresh = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        return SyncFolder(url: url)
    }

    /// Appends one line to this device's own file, through a file coordinator like the real sync will.
    func appendOwnLine() throws {
        let fileURL = url.appendingPathComponent(Self.ownFileName)
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = Data((#"{"device":"iphone","at":"\#(stamp)"}"# + "\n").utf8)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { target in
            do {
                if FileManager.default.fileExists(atPath: target.path) {
                    let handle = try FileHandle(forWritingTo: target)
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                } else {
                    try line.write(to: target)
                }
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    /// What was found for one file in the folder.
    struct FileReport: Identifiable, Sendable {
        let id: String
        let status: String
        let lineCount: Int?
        let lastLine: String?
    }

    /// Lists the folder's files, asks iCloud to download any that aren't on the phone, and reads each one
    /// through a file coordinator (which waits for the download). Blocking: call off the main thread.
    func listFiles() throws -> [FileReport] {
        let items = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .ubiquitousItemDownloadingStatusKey], options: [])
        var reports: [FileReport] = []
        for item in items {
            var name = item.lastPathComponent
            var target = item
            // Older-style iCloud placeholder for a file not on this device: ".name.jsonl.icloud".
            let isPlaceholder = name.hasPrefix(".") && name.hasSuffix(".icloud")
            if isPlaceholder {
                name = String(name.dropFirst().dropLast(".icloud".count))
                target = url.appendingPathComponent(name)
            } else if name.hasPrefix(".") {
                continue
            }
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { continue }

            let before = Self.downloadStatus(of: item)
            if before != .current {
                try? FileManager.default.startDownloadingUbiquitousItem(at: target)
            }
            let read = Self.coordinatedRead(target)
            let lines = read.text?.split(separator: "\n", omittingEmptySubsequences: true)
            let outcome = read.error.map { "read failed: \($0)" } ?? "read OK"
            reports.append(FileReport(
                id: name,
                status: "Before reading: \(Self.describe(before, isPlaceholder: isPlaceholder)) · \(outcome)",
                lineCount: lines?.count,
                lastLine: lines?.last.map(String.init)))
        }
        return reports.sorted { $0.id < $1.id }
    }

    private static func downloadStatus(of url: URL) -> URLUbiquitousItemDownloadingStatus? {
        try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
    }

    private static func describe(_ status: URLUbiquitousItemDownloadingStatus?, isPlaceholder: Bool) -> String {
        if status == .current { return "on the phone, up to date" }
        if status == .downloaded { return "on the phone, older version" }
        if status == .notDownloaded { return isPlaceholder ? "not on the phone (placeholder)" : "not on the phone" }
        return isPlaceholder ? "placeholder" : "not an iCloud file"
    }

    private static func coordinatedRead(_ url: URL) -> (text: String?, error: String?) {
        var coordinationError: NSError?
        var text: String?
        var readError: String?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { target in
            do {
                text = try String(contentsOf: target, encoding: .utf8)
            } catch {
                readError = error.localizedDescription
            }
        }
        if let coordinationError { readError = coordinationError.localizedDescription }
        return (text, readError)
    }
}
