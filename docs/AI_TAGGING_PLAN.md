# Plan: Offline AI tagging & contextual search

Status: **Draft for review** · Branch: `feature/local-ai-tagging` (off `feature/search`)

A planning document, not final. It records what we agreed and the decisions
still open, so the build can proceed in reviewable steps.

---

## 1. Goal

Let a user find the days they *described* a certain way — "low", "flat",
"anxious" — by meaning, not by substring. Searching "low" should surface a
day written as "felt completely empty, couldn't get up" and must **not** match
"followed" or "low-tolerance".

The chosen approach: a small open-weight language model, running **fully
offline on the user's own machine**, reads each entry once and assigns it tags
from a fixed vocabulary. The tags are stored. Search then filters on tags and
is instant. The model never runs at search time and nothing ever leaves the
device.

## 2. Why this, and the wider context

This app is moving from a personal tool toward something that may be shared,
for free, with people in a similar position — possibly on Windows too. That
shapes several choices below (portability, model licence, resource use,
safety framing). Two commitments sit above the technical detail:

- **Privacy is non-negotiable.** A mental-health diary stays on the device.
  Offline inference is a feature, not an optimisation.
- **It is a reflection tool, not a diagnosis.** AI tags and episode detection
  are heuristic. Framing, wording, and the detection algorithms are to be
  re-examined against clinical criteria and reviewed with a therapist before
  any public release. That review is a release gate, tracked here, not an
  afterthought.

## 3. Guiding principles

1. **Offline & private** — no network calls for inference, ever.
2. **Classify once, store the result** — one inference per new/edited entry;
   search reads stored tags. Search latency unchanged.
3. **Fixed taxonomy** — the model maps free text onto a closed set of tags, so
   results stay consistent and searchable (not free-form tag sprawl).
4. **Cross-platform-ready** — the inference layer is portable (llama.cpp),
   isolated behind a protocol so a Windows port is a smaller, later lift.
5. **Degrade gracefully** — if the model is unavailable or classification
   fails, the app works exactly as it does today; literal search still works.
6. **Reversible & transparent** — tags are derived data. The user can see
   them, a "reclassify all" exists, and raw entries are never modified by it.

## 4. Runtime & model (decided)

- **Runtime:** `llama.cpp` (GGUF models). Runs on macOS (Apple Silicon +
  Intel), Windows, Linux from one codebase; uses Metal on a Mac. Chosen over
  MLX (Apple-only) because of the cross-platform goal.
- **Model:** small **Qwen2.5 instruct** (0.5B or 1.5B), **Apache-2.0** — a
  licence that permits free redistribution. A 0.5B–1.5B model is ample for
  mapping text onto a fixed tag set, keeps the download small, and runs on
  modest/older hardware. Final size (0.5B vs 1.5B) to be settled by testing
  quality against speed on real entries.
- **Integration:** llama.cpp via a Swift wrapper (SwiftPM package such as
  LLM.swift / llama.cpp bindings, or a thin C-interop target vendoring
  llama.cpp). Exact binding to be chosen in Phase 1.

## 5. The classification contract

- **Input:** the entry's title + note (and nothing else; mood number is not
  fed in, to keep tags grounded in what the user *wrote*).
- **Output:** a subset of a fixed tag vocabulary, plus an optional per-tag
  confidence. Produced via constrained/structured generation so the model
  can only return valid tags (grammar-constrained decoding in llama.cpp, or
  parse-and-validate against the vocabulary).
- **Taxonomy (SEED — needs the user's real vocabulary):**
  `low, flat, numb, anxious, irritable, overwhelmed, restless, hopeful,
  calm, content, energised, elevated, foggy, tired, lonely`.
  This is a placeholder. The real set should come from words the user
  actually uses, and be reviewed with the therapist. The vocabulary lives in
  one place in code (a `MoodTag` enum / list) so it is easy to revise.
- **Prompt:** a fixed system instruction describing the task and the allowed
  tags, kept in the repo and versioned.

## 6. Data model changes

Add to `moodEntry` (new GRDB migration, same backfill pattern as `localDate`):

| Column          | Type | Purpose                                                        |
|-----------------|------|----------------------------------------------------------------|
| `tags`          | text | Tags for this entry (e.g. JSON array or comma list)            |
| `tagModelVersion` | text | Model + taxonomy version that produced them; drives re-tagging |

- `tags` empty = not yet classified (mirrors how `localDate` backfill works).
- `tagModelVersion` lets a model or taxonomy change trigger re-classification
  of stale rows without touching current ones.
- CSV/JSON export gains a `tags` column.

## 7. Tagging lifecycle

- **New entry / edit:** after save, enqueue classification; write tags back
  when done. Runs off the main thread; the UI never blocks on the model.
- **Backfill:** a one-time pass classifies existing untagged entries, shown
  with progress. Resumable; safe to interrupt.
- **Taxonomy / model change:** bump `tagModelVersion`; a "reclassify all"
  action re-tags everything. Manual, never automatic on launch.
- **Failure:** entry is left untagged and retried later; never blocks saving.

## 8. UI integration

Reuses the search UI from `feature/search` with minimal change:

- Searching a known tag word filters by **tag** (semantic) in addition to the
  existing literal title/note match — so "low" finds tagged days plus any
  literal "low " occurrences, without the "followed" noise for the tag part.
- Decision to settle in design: a distinct "tags" affordance (chips/filter)
  vs. folding tags transparently into the one search box. Leaning toward
  showing an entry's tags in the detail panel and offering tag chips to
  filter, so the feature is visible and trusted.
- Diagram rings, match count, list filtering, arrow-step: unchanged, they
  operate on whatever set the search returns.

## 9. Cross-platform boundary (for the future Windows port)

- All inference behind a protocol, e.g. `EntryClassifier` with a single
  `classify(title:note:) -> [MoodTag]`. SwiftUI and persistence depend on the
  protocol, not on llama.cpp.
- The macOS build provides a `LlamaClassifier`. A future Windows build (Swift
  on Windows, or a re-implementation) provides its own conformance over the
  same llama.cpp core. Nothing else changes.
- Keep the taxonomy, prompt, and tag-storage format platform-neutral (plain
  data), so both platforms produce comparable tags.

## 10. Distribution & resources

- **Model delivery:** bundle in the app vs. download on first launch.
  Open decision (§13). Leaning first-run download to keep the installer small
  and the model updatable, with a clear offline-after-download promise.
- **App size / memory:** 0.5B–1.5B GGUF is roughly a few hundred MB to ~1 GB
  on disk; memory use modest. Confirm on low-end hardware.
- **Licence hygiene:** ship Qwen's Apache-2.0 licence and attribution; audit
  that the chosen Swift/llama.cpp bindings are redistributable too.

## 11. Safety & framing (release gate)

- Keep "reflection, not clinical" framing throughout; label AI tags as
  automatic and approximate.
- Re-examine episode-detection thresholds/durations against DSM criteria
  (the bipolar II work already started) and review wording and tags with the
  therapist friend before public release.
- No telemetry. Document the privacy model plainly for users.

## 12. Testing

- Unit-test the taxonomy mapping and tag storage/migration with fixed inputs.
- Golden-set test: a handful of example notes with expected tags, to catch
  regressions when model/prompt/taxonomy change.
- **Caveat:** llama.cpp inference cannot be compiled or run in this authoring
  environment. Model loading and real inference are validated locally by the
  user, as with the rest of the app. Expect first-run model-loading issues to
  surface there.

## 13. Open decisions

1. **Model size:** Qwen2.5 **0.5B vs 1.5B** — decide by quality-vs-speed test
   on real entries.
2. **Model delivery:** bundle vs first-run download.
3. **Tag vocabulary:** the real seed list from the user (10–20 words), then a
   therapist review.
4. **Confidence:** store per-tag confidence, or tags only?
5. **Search UX:** visible tag chips/filter vs. tags folded into the one box.

## 14. Phased rollout

- **Phase 0 — Plan & decisions** (this doc): settle §13 items 1–3 at least.
- **Phase 1 — Inference spike:** wire llama.cpp + Qwen behind `EntryClassifier`;
  prove one note → tags locally. No UI, no DB yet.
- **Phase 2 — Schema & service:** `tags`/`tagModelVersion` migration,
  classification on save, async queue, failure handling.
- **Phase 3 — Backfill & reclassify:** one-time pass + "reclassify all".
- **Phase 4 — Search UX:** tag display in detail panel, tag filtering folded
  into search, exports include tags.
- **Phase 5 — Hardening:** golden-set tests, resource checks on low-end
  hardware, licence audit.
- **Phase 6 — Safety review (release gate):** algorithm re-examination +
  therapist review before any public/Windows release.

## 15. Out of scope (for now)

- Windows build itself (only the boundary that enables it later).
- Charting/analytics over tags (natural follow-up once tags exist).
- Any cloud or networked feature.
