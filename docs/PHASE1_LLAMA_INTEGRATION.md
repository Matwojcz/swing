# Phase 1 — wiring the real model (local steps)

This is the part that can't be done in the cloud session: adding llama.cpp +
a Qwen model and running it on your Mac. The app already compiles and runs
with a stub (`KeywordClassifier`) so the harness, taxonomy, prompt and parsing
can be tested now; this doc swaps in the real model.

Everything the app depends on is behind `EntryClassifier`, so adding the model
is: add a dependency, add one file, change one line.

## What already exists (committed, compiles without the model)

- `MoodTag` — the closed 20-tag vocabulary.
- `EntryClassifier` — the protocol everything depends on.
- `TagPrompt` — builds the system/user prompt and parses + validates the reply
  down to valid tags, up to 2 per part of the day (max 4). Model-agnostic.
- `KeywordClassifier` — dependency-free stub + fallback.
- `TagSpikeView` — the "paste text → tags" screen, opened from the toolbar
  "Tag spike" button. Wired to `spikeClassifier` in `ContentView`.

## Step 1 — add the llama.cpp Swift binding

Suggested: **LLM.swift** (`eastriverlee/LLM.swift`), a small SwiftPM wrapper
over llama.cpp with Metal on Apple Silicon. Alternatives: `swift-llama`, or
vendoring llama.cpp directly with its SwiftPM target. Whichever you pick, the
only code that touches it is `LlamaClassifier` below.

In `project.yml`, add the package and depend on it:

```yaml
packages:
  GRDB:
    url: https://github.com/groue/GRDB.swift.git
    from: 7.0.0
  LLM:
    url: https://github.com/eastriverlee/LLM.swift
    from: 1.4.0            # pin to whatever the current release is
targets:
  Swing:
    dependencies:
      - package: GRDB
        product: GRDB
      - package: LLM
        product: LLM
```

Then `xcodegen generate`.

## Step 2 — get the model (Qwen2.5 instruct, GGUF, Apache-2.0)

Download a quantised GGUF, e.g. from the official Qwen GGUF repos on Hugging
Face. Start with **0.5B** (fastest/smallest) and keep **1.5B** handy to
compare — tagging may be fine on 0.5B, import likely wants 1.5B.

- Suggested quant: `Q4_K_M` (good size/quality balance).
- For the spike, drop the `.gguf` somewhere local and point at it by path.
  For shipping later we decide bundle vs first-run download (§13 of the plan).

## Step 3 — add `LlamaClassifier`

Create `Sources/MoodBattery/AI/LlamaClassifier.swift`. This sketch matches
LLM.swift's API shape; **verify names against the version you pinned** — this
is the one file that may need small tweaks when you compile. Qwen uses the
ChatML template.

```swift
import Foundation
import LLM

/// On-device classifier backed by llama.cpp + a local Qwen GGUF. The only type that imports the
/// model binding; everything else depends on `EntryClassifier`.
actor LlamaClassifier: EntryClassifier {
    private let llm: LLM

    /// - Parameter modelURL: path to the local .gguf file.
    init(modelURL: URL) throws {
        // ChatML template with our fixed system instruction baked in.
        guard let llm = LLM(from: modelURL, template: .chatML(TagPrompt.system)) else {
            throw ClassifierError.modelLoadFailed
        }
        llm.maxTokenCount = 2048   // generous headroom for prompt + short reply
        self.llm = llm
    }

    func classify(title: String?, note: String?) async throws -> [MoodTag] {
        let prompt = TagPrompt.user(title: title, note: note)
        let reply = await llm.getCompletion(from: prompt)
        return TagPrompt.parse(reply)   // validates + caps at 3, drops anything off-list
    }

    enum ClassifierError: Error { case modelLoadFailed }
}
```

Notes:
- `TagPrompt.parse` already discards anything not in the tag set, so even a
  chatty or malformed reply degrades to valid tags (or none).
- **Optional hardening:** constrain decoding with a GBNF grammar so the model
  *can only* emit valid tags. Nice-to-have; `parse` makes it non-essential for
  the spike.
- Keep all of this off the main thread (it's an `actor`); the UI already calls
  `classify` from a `Task`.

## Step 4 — point the spike at it

In `ContentView`, swap the one line:

```swift
// private let spikeClassifier: EntryClassifier = KeywordClassifier()
private let spikeClassifier: EntryClassifier =
    (try? LlamaClassifier(modelURL: URL(fileURLWithPath: "/path/to/qwen2.5-0.5b-instruct-q4_k_m.gguf")))
    ?? KeywordClassifier()   // falls back to the stub if the model can't load
```

Build, run, open **Tag spike** from the toolbar, paste real entries.

## The Phase 1 gate — decide before building Phase 2

Run ~20–30 of your **real** past entries through the spike and check:

1. **Offline** — disconnect the network; it still works.
2. **Quality** — tags are sensible more often than not. If 0.5B is weak, try
   1.5B here (cheap to swap). If still poor, stop and rethink before building
   persistence on top.
3. **Speed** — seconds per entry, not minutes.
4. **Memory** — no runaway memory; acceptable on your machine (and ideally a
   modest one).
5. **Containment** — every tag returned is from the 20-tag set (guaranteed by
   `parse`, but confirm nothing odd shows up).

Record the 0.5B-vs-1.5B verdict and the bundle-vs-download leaning; those two
decisions unblock Phase 2. Only proceed once quality clears the bar.
