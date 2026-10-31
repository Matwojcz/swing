import Foundation
import Observation

/// Owns the on-device tagger and runs it for one entry or a whole-history pass, publishing progress
/// for the UI. The model loads on first use, off the main thread, so the app launches without it.
@MainActor
@Observable
final class TaggingController {
    enum Activity: Equatable {
        case idle
        case single(entryID: Int64)
        case batch(done: Int, total: Int)
    }

    enum TaggingError: LocalizedError {
        case modelMissing(String)

        var errorDescription: String? {
            switch self {
            case .modelMissing(let path): "The tagging model wasn't found at \(path)."
            }
        }
    }

    static let modelURL = URL(fileURLWithPath: "/Users/matwojcz/Models/gemma-4-E2B-it-Q4_K_M.gguf")
    /// Stored on every tagged entry. Entries carrying a different version count as untagged.
    static let version = "\(modelURL.deletingPathExtension().lastPathComponent)/\(TagPrompt.version)"
    /// Measured on an M4 Pro (about 2.4 s per entry in the harness); used for the estimate before any entry has run.
    static let estimatedSecondsPerEntry = 2.4

    private(set) var activity: Activity = .idle
    private(set) var isLoadingModel = false
    /// Live estimate during a batch, from the average time per entry so far.
    private(set) var secondsRemaining: Double?
    var errorMessage: String?

    private var classifier: EntryClassifier?
    /// The single-entry or batch run in progress.
    private var task: Task<Void, Never>?
    private let store = MoodEntryStore()

    var isBusy: Bool { activity != .idle }

    static func isTagged(_ entry: MoodEntry) -> Bool { entry.tagModelVersion == version }

    /// Tags one entry and hands the saved result to `onTagged`.
    func autoTag(_ entry: MoodEntry, onTagged: @escaping (MoodEntry) -> Void) {
        guard !isBusy, let id = entry.id else { return }
        activity = .single(entryID: id)
        task = Task {
            defer {
                activity = .idle
                task = nil
            }
            do {
                if let tagged = try await tag(entry) {
                    onTagged(tagged)
                } else {
                    errorMessage = "The model didn't return any tags for this entry. Try again, or edit the note first."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Tags `entries` one at a time (in the order given), calling `onTagged` after each is saved.
    /// An entry that fails is left untagged and the pass carries on; `cancelBatch()` stops after the current entry.
    func autoTagAll(_ entries: [MoodEntry], onTagged: @escaping (MoodEntry) -> Void) {
        guard !isBusy, !entries.isEmpty else { return }
        activity = .batch(done: 0, total: entries.count)
        secondsRemaining = Double(entries.count) * Self.estimatedSecondsPerEntry
        task = Task {
            defer {
                activity = .idle
                secondsRemaining = nil
                task = nil
            }
            do {
                _ = try await loadedClassifier()
            } catch {
                errorMessage = error.localizedDescription
                return
            }
            let started = Date()
            var failed = 0
            for (index, entry) in entries.enumerated() {
                if Task.isCancelled { break }
                if let tagged = try? await tag(entry) {
                    onTagged(tagged)
                } else {
                    failed += 1
                }
                let done = index + 1
                activity = .batch(done: done, total: entries.count)
                secondsRemaining = Date().timeIntervalSince(started) / Double(done) * Double(entries.count - done)
            }
            if failed > 0 {
                errorMessage = "\(failed) \(failed == 1 ? "entry" : "entries") couldn't be tagged and \(failed == 1 ? "was" : "were") left untagged. Run Auto-tag again to retry them."
            }
        }
    }

    func cancelBatch() {
        task?.cancel()
    }

    /// Lets the entry being tagged finish (a batch stops after it), then frees the model. Call before the app exits:
    /// ggml aborts if a loaded model's Metal buffers outlive its global Metal device, which a static destructor frees.
    func releaseModel() async {
        task?.cancel()
        await task?.value
        releaseIdleModel()
    }

    /// Frees the model straight away. Only enough while idle: a run in progress holds its own reference.
    func releaseIdleModel() {
        classifier = nil
    }

    /// Classifies and saves one entry. Returns nil when the entry was deleted meanwhile or the model gave no tags.
    private func tag(_ entry: MoodEntry) async throws -> MoodEntry? {
        guard let id = entry.id else { return nil }
        let classifier = try await loadedClassifier()
        let tags = try await classifier.classify(title: entry.title, note: entry.note)
        guard !tags.isEmpty else { return nil }
        return try store.setTags(tags, version: Self.version, forEntryID: id)
    }

    private func loadedClassifier() async throws -> EntryClassifier {
        if let classifier { return classifier }
        let url = Self.modelURL
        guard FileManager.default.fileExists(atPath: url.path) else { throw TaggingError.modelMissing(url.path) }
        isLoadingModel = true
        defer { isLoadingModel = false }
        let loaded = try await Task.detached(priority: .userInitiated) { try LlamaClassifier(modelURL: url) }.value
        classifier = loaded
        return loaded
    }
}
