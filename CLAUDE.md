# Swing

An interactive, slightly playful bipolar mood tracker. Not a clinical tool —
a personal, visual way to log and reflect on mood state over time.

## Core concept

A semicircular gauge is the primary interaction — a dial with a needle
that the user drags to set mood (0–100):

- A colored band sweeps the arc: black at the depressive floor, through
  purple, up to blue at baseline (50), then warming into gold/orange
  or red/magenta above baseline depending on a second "flavour"
  slider (0 = calm, 0.5 = normal, 1 = irritable).
- A dashed baseline tick sits at the 50 mark, echoing a tachometer's
  reference mark.
- Past ~88, a "redline" zone with tick marks and spark particles
  represents a hype phase that exceeds normal range.

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
3. **Diagram** — mood over time with mood-colored line; supports
   week/month/year scales with pinch-to-zoom and paging. Tappable
   date labels in week view. Lines connect across page boundaries.
4. **Entry detail panel** — tap a history entry to open an overlay
   showing full note/title with inline editing (double-click any
   field: mood, flavour, title, note), delete, and mood data.
5. **Markdown import** — import .md diary files with preview sheet;
   parses dates, mood/flavour from fields or text sentiment.
6. **Delete-all confirmation** — warning dialog before clearing entries.
7. **One entry per day** — blocks duplicate entries for the same day.
8. **Retrospective entries** — tap an empty date label in the week
   diagram to log for that past day.
9. **Data export** — export all entries as CSV or JSON via NSSavePanel.
10. **MCP server** — Python server for Claude integration, supports
    logging, querying, updating, and deleting entries.

## Planned features

11. **iCloud backup** — move SQLite to an iCloud Drive container for
    automatic cloud backup.
12. **Diary function** — richer free-text notes attached to entries,
    searchable.
13. (Maybe) trends/insights — but keep this descriptive, not diagnostic.
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
