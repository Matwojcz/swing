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
7. **Neutral core, optional lenses** — out of the box the app is a general
   mood tracker that implies no diagnosis. Condition-specific framing is
   opt-in (see §4a).

## 4a. Product direction: neutral core & lenses

The app is becoming something that may be shared freely with people across
different conditions (bipolar I/II, cyclothymia, BPD, PMDD, MDD, or no
diagnosis at all). To serve all of them without fragmenting into separate
per-condition apps:

- **Neutral core (default, out of the box).** Log mood on the existing 0–10
  scale + flavour axis, add notes, get AI tags. Neutral wording, no diagnosis
  implied. This is what every new user sees.
- **Lenses (opt-in, later — once settings exist).** A switch in settings turns
  on a lens that reframes the *same data* for a user's situation. The first is
  a **Bipolar lens**: it brings back the blunt direct language
  ("depressive / elevated") and the episode bands. Future lenses could frame
  the same data other ways. One app, neutral by default, depth on request.
- **The scale stays 0–10.** We do **not** widen it for mania. Instead mania
  becomes a new **detection tier inside the Bipolar lens** (the tier we
  deferred earlier — e.g. a ≥7-day elevated run, or a user-flagged
  hospitalisation — distinct from the 4-day hypomania tier). Keeping 0–10
  keeps all existing data valid.
- **Tags do the cross-condition work.** Tags describe *states as written*
  (anxious, numb, irritable, elevated…), not diagnoses, so one simple scale
  plus multi-tagging covers very different conditions without special-casing.

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
- **Output:** up to **3** tags from a fixed vocabulary — **binary** (present or
  not; no confidence score, which a small model can't report honestly).
  Produced via constrained/structured generation so the model can only return
  valid tags (grammar-constrained decoding in llama.cpp, or parse-and-validate
  against the vocabulary).

### Taxonomy design (decided; wording pending therapist review)

Settled choices: **two-dimensional** (valence × arousal, not a single
sad↔happy line); **multi-label, max 3** per entry; **vernacular** register in
the core (clinical words live in the Bipolar lens); **medium** size (~20);
**closed** set (the model may not invent tags); **feelings only** (no context/
trigger tags yet); **binary** (no confidence).

**Provisional base set — 20 tags, on the valence × arousal grid:**

| valence \\ arousal | low arousal (still)        | high arousal (activated)                        |
|--------------------|----------------------------|-------------------------------------------------|
| **low (bad)**      | low, flat, numb, tired, foggy, lonely | anxious, restless, overwhelmed, irritable, frustrated, angry |
| **high (good)**    | calm, content, rested      | happy, hopeful, energised, excited              |
| **neutral**        | okay                       |                                                 |

- **Clinical words reserved for the Bipolar lens** (opt-in): `depressed`,
  `euphoric`, `manic`, `hypomanic`, `dysphoric/mixed`. The blunt no-euphemism
  language stays available to those who turn the lens on; the neutral core
  avoids implying diagnosis.
- **`hopeless` is deliberately held back** from the base: vernacular and common
  but a weighty, safety-adjacent signal. Decide its handling (core / lens /
  special treatment) **with the therapist**, not silently.
- Lives in one place in code (a `MoodTag` enum / list), easy to revise.
- **Still open for a NEXT version** (parked, revisit once the LLM works): final
  wording sign-off with the therapist; a separate *context/trigger* tag
  dimension (poor sleep, argument…) as its own layer, never mixed into these;
  optional manual personal tags the user applies by hand (the AI stays on the
  closed set).
- **Prompt:** a fixed system instruction describing the task, the allowed tags,
  and the "up to 3 strongest, only if clearly present" rule. Kept in the repo
  and versioned.

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

## 10a. Smart diary import (later phase, builds on the classifier)

Upgrade the existing Markdown importer so a user can bring in a digitised
diary of **any layout** — not just the formats the current regex parser
anticipates. The model does only the fuzzy structural work; everything else
reuses what already exists.

- **The LLM identifies exactly three things per entry:** where each entry
  **starts/stops** (segmentation), its **date**, and its **title**. Nothing
  more.
- **Content is sliced verbatim** from the source by position — never
  regenerated or paraphrased — so the model cannot hallucinate or reword
  someone's actual diary text.
- **Two kinds of "format" are handled in different layers:**
  - *Internal structure* (date-first vs date-last, headers, bullet-journal,
    run-on prose) → the LLM absorbs this; that is the point of using it.
  - *File/container format* (.txt, .md, .docx, .pdf, exported JSON) → a
    deterministic adapter layer converts the file to plain text first, then
    hands that text to the LLM. txt/md are trivial; .docx/.pdf need text
    extraction via platform APIs, kept behind the same cross-platform
    boundary as the model so Windows stays a clean port. (Today's importer
    accepts `.plainText` only — this is where the breadth is added.)
- **Reuses the existing import *preview* sheet.** The model *proposes* entries;
  the user reviews and confirms before anything is committed. That existing
  review step is the safety net that makes LLM import trustworthy, especially
  for dates (the easiest thing for a small model to get wrong).
- **Tags + suggested mood** are applied to each isolated entry via the same
  classifier, adjustable in preview.
- **Pipeline:** `file → (adapter) → plain text → (LLM: date/title/boundaries)
  → verbatim slices → existing preview → commit (+ tags)`.
- **Model note:** extraction is harder than tagging; it may want the 1.5B
  model even if 0.5B suffices for tags. Settle during the Phase 1 spike.
- Runs as a slow, resumable background job with progress — acceptable because
  it is a one-off per imported file.

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

Settle **before Phase 1** (they gate the first build):

1. **Model size:** Qwen2.5 **0.5B vs 1.5B** — decide by quality-vs-speed test
   on real entries (tagging may be fine on 0.5B; import may want 1.5B).
2. **Model delivery:** bundle vs first-run download.

**Taxonomy shape is now decided** (§5): two-dimensional, multi-label max 3,
vernacular core, ~20 closed tags, feelings-only, binary. What remains:

3. **Wording sign-off with the therapist** — the provisional 20-tag set, and
   the handling of `hopeless` specifically.

Parked for a **NEXT version — revisit once the LLM works as it should**:

4. **Context/trigger tag dimension** and optional manual personal tags.
5. **Lenses & settings** — the opt-in lens switch and the Bipolar lens
   (clinical language + episode bands + the new **mania detection tier**).
6. **Search UX** — visible tag chips/filter vs. tags folded into the one box.

## 14. Phased rollout

**Get local inference working first; everything opinionated comes after.**

- **Phase 0 — Plan & decisions** (this doc): settle §13 items 1–2.
- **Phase 1 — Inference spike:** wire llama.cpp + Qwen behind `EntryClassifier`;
  prove one note → tags locally. No DB yet. *This is the gate: nothing below is
  worth finalising until this works.* Scaffolding (protocol, taxonomy, prompt +
  validation, stub classifier, "Tag spike" harness screen) is **built and
  compiles without the model**; the local model-wiring steps and the gate
  checklist are in `docs/PHASE1_LLAMA_INTEGRATION.md`.
- **Phase 2 — Schema & service:** `tags`/`tagModelVersion` migration,
  classification on save, async queue, failure handling.
- **Phase 3 — Backfill & reclassify:** one-time pass + "reclassify all".
- **Phase 4 — Search UX:** tag display in detail panel, tag filtering folded
  into search, exports include tags.
- **Phase 5 — Finalise taxonomy & smart import:** lock the tag vocabulary
  (§13.3) now that real tagging can be observed; build smart diary import
  (§10a) on the proven classifier.
- **Phase 6 — Lenses & mania tier:** settings switch, Bipolar lens (direct
  language + episode bands + mania detection tier), neutral-core default.
- **Phase 7 — Hardening:** golden-set tests, resource checks on low-end
  hardware, licence audit.
- **Phase 8 — Safety review (release gate):** algorithm re-examination +
  therapist review before any public/Windows release.

## 15. Out of scope (for now)

- Windows build itself (only the boundary that enables it later).
- Charting/analytics over tags (natural follow-up once tags exist).
- Any cloud or networked feature.
