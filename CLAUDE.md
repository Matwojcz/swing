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

1. **Logging** — save a mood entry (mood 0–100, flavour 0–1, optional
   title and note, timestamp) to the local database.
2. **History view** — scrollable, mood-colored entry list with date
   column, Dock-style magnification on hover, bottom fade mask, and
   liquid glass effects (macOS 26+).
3. **Weekly/monthly/yearly diagram** — mood over time, per-day or
   per-week averaged, line colored via the same MoodColor stops so it
   visually echoes the gauge. Clickable dots to select entries.
4. **Entry detail panel** — tap a history entry to open a side panel
   showing the full note and entry data. Double-click any field (mood,
   flavour, title, note) to edit inline.
5. **Markdown import** — import existing diary files (.md) to extract
   and backfill entries with dates, with preview before confirming.
6. **MCP server** — Python server for Claude integration, supports
   logging, querying, updating, and deleting entries.

## Planned features

7. **Diagram gap fix** — connect the mood line across page boundaries
   so there's no visual break between weeks/months.
8. **iCloud backup** — move SQLite to an iCloud Drive container for
   automatic cloud backup.
9. **Diary function** — richer free-text notes attached to entries,
   searchable.
10. (Maybe) trends/insights — but keep this descriptive, not diagnostic.
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
