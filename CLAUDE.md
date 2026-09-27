# Mood battery

An interactive, slightly playful bipolar mood tracker. Not a clinical tool —
a personal, visual way to log and reflect on mood state over time.

## Core concept

A semicircular gauge is the primary interaction — a dial with a needle
that the user drags to set energy (0–100):

- A colored band sweeps the arc: black at the depressive floor, through
  purple, up to blue at baseline (50), then warming into happy gold/orange
  or irritable red/magenta above baseline depending on a second "flavour"
  slider (0 = happy hype, 1 = irritable hype).
- A dashed baseline tick sits at the 50 mark, echoing a tachometer's
  reference mark.
- Past ~88, a "redline" zone with tick marks and spark particles
  represents a hype phase that exceeds normal range — a gauge needle
  entering a marked danger zone is a more natural metaphor for overshoot
  than a container overflowing (the reason the earlier tank/battery
  visual was retired).

The original `index.html` prototype used a tank/battery visual; the gauge
replaced it in July 2026. `index.html` remains in the repo as a color-
language reference but is not the active UI.

## Tech stack

- **Platform**: native macOS app, SwiftUI.
- **Build**: XcodeGen (`project.yml`) generates the Xcode project.
- **Storage**: SQLite via GRDB.swift — local-only for now.

## Completed features

1. **Logging** — save a mood entry (energy, flavour, optional title,
   note, timestamp) to the local database.
2. **History view** — scrollable, mood-colored entry list with fade mask.
3. **Diagram** — energy over time with mood-colored line; supports
   week/month/year scales with pinch-to-zoom and paging.
4. **Entry detail panel** — tap a history entry to open an overlay
   showing full note/title with inline editing, delete, and mood data.
5. **Markdown import** — import .md diary files with preview sheet;
   parses dates, mood/flavour from fields or text sentiment.
6. **Notes** — title and free-text note fields on entries (diary
   function minus search).

## Planned features (roughly in build order)

7. **Delete-all confirmation** — show a warning/confirmation dialog
   before deleting all entries.
8. **One entry per day** — block the logger from adding a second entry
   when one already exists for that calendar day.
9. **Retrospective entries** — tap a date in the weekly diagram to open
   the logger pre-filled with that date, allowing past-day entries.
10. **Note search** — search/filter entries by note and title text.
11. (Maybe) trends/insights — but keep this descriptive, not diagnostic.
    Never present pattern detection as a clinical claim.

## Tone and framing rules

- This app names things directly (depressive, hype, baseline) rather than
  euphemistically — that's an intentional choice, keep it.
- Never add copy that pathologizes normal mood variation, and never
  present the app's output as a diagnosis or clinical assessment.
- Keep the visual language consistent: the gauge's color language should
  extend into the weekly diagram and history views rather than switching
  to generic bar charts.

## Working conventions

- Commit after each completed subtask, with a clear message.
- Keep the gauge component visually isolated (its own file/module) so it
  can be reused unchanged in both the daily entry view and any future
  weekly/summary view.
