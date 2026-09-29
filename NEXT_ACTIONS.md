# Next Actions — Refactoring for Low Coupling / High Cohesion

This is a checklist of refactors identified in the coupling/cohesion audit. Action these in the next prompt (not now). When actioning, **update all affected function doc comments** so they still describe the code accurately.

## 1. Extract `EpisodeDetector`
- **From:** `Sources/MoodBattery/Weekly/MoodDiagramView.swift` (lines ~497-617 — `globalEpisodes`, `Episode`, `EpisodeType`, `scan()` closure)
- **To:** New file `Sources/MoodBattery/Models/EpisodeDetector.swift`
- **Interface:** `static func detect(entries: [MoodEntry], calendar: Calendar) -> [Episode]`
- **Comments to refresh:** `globalEpisodes` (removed), any new methods on the extractee.

## 2. Extract `MoodDataAggregator`
- **From:** `Sources/MoodBattery/Weekly/MoodDiagramView.swift` (`dailyAverages`, `weeklyAverages`, `entriesByDay`, `dataPoints`)
- **To:** New file `Sources/MoodBattery/Models/MoodDataAggregator.swift`
- **Interface:** `static func dailyAverages(entries:days:) -> [DataPoint]` and `static func weeklyAverages(entries:days:) -> [DataPoint]`
- **Comments to refresh:** `dailyAverages`, `weeklyAverages`, `dataPoints`, `entriesByDay` — all move.

## 3. Centralise flavour labels in `MoodScale`
- Add `static func flavourLabel(_ v: Double) -> String` to `Sources/MoodBattery/Models/MoodScale.swift`
- **Callers to update** (each currently duplicates the 0.35/0.65 thresholds):
  - `Sources/MoodBattery/Entry/MoodEntryEditor.swift` — `flavourLabel` computed property
  - `Sources/MoodBattery/History/EntryDetailPanel.swift` — `flavourLabel` computed property
  - `Sources/MoodBattery/Import/ImportView.swift` — `flavourLabel(_:)` function
  - `Sources/MoodBattery/Tank/MoodState.swift` — inline in `label(mood:flavour:)`
- **Comments to refresh:** the 4 duplicate `flavourLabel`s (delete or update to reference `MoodScale.flavourLabel`), plus new `MoodScale.flavourLabel` doc comment.

## 4. Remove `MoodEntryStore` instances from views/importers
- **Files:**
  - `Sources/MoodBattery/Entry/MoodEntryEditor.swift` — remove `private let store = MoodEntryStore()`; inject via env or pass a save closure from parent.
  - `Sources/MoodBattery/Import/MarkdownImporter.swift` — remove `private let store = MoodEntryStore()`; split `importFile(at:)` so parsing is pure and the caller (ContentView) does the saving.
- **Comments to refresh:** `save()` in MoodEntryEditor, `importFile(at:)` in MarkdownImporter.

## 5. Separate `MoodEntry` GRDB conformance
- **From:** `Sources/MoodBattery/Models/MoodEntry.swift`
- **To:** New file `Sources/MoodBattery/Persistence/MoodEntry+GRDB.swift`
- Move the `extension MoodEntry: FetchableRecord, MutablePersistableRecord` block and drop `import GRDB` from the model file.
- **Comments to refresh:** `didInsert(_:)` moves.

## 6. Extract export logic into `ExportService`
- **From:** `Sources/MoodBattery/ContentView.swift` (`exportCSV`, `exportJSON`, `saveFile`, `csvEscape`, `iso8601Formatter`)
- **To:** New file `Sources/MoodBattery/Export/ExportService.swift`
- **Interface:** `static func csv(from: [MoodEntry]) -> String`, `static func json(from: [MoodEntry]) throws -> String`. Keep `NSSavePanel` in ContentView (view concern).
- **Comments to refresh:** all 4 export helpers (removed from ContentView, new ones on ExportService).

## 7. Delete dead code
- **File:** `Sources/MoodBattery/Weekly/WeeklyDiagramView.swift`
- **Check:** Confirm nothing references it (grep for `WeeklyDiagramView`). If unreferenced, delete.
- **Comments to refresh:** N/A (whole file removed).

---

## Reminder when actioning
**Every function comment added in the last commit must stay accurate.** After each refactor, re-scan the touched files and update or remove doc comments so they describe the new behaviour, not the old one.
