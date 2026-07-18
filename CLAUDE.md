# Mood battery

An interactive, slightly playful bipolar mood tracker. Not a clinical tool —
a personal, visual way to log and reflect on mood state over time.

## Core concept

A battery/tank visual is the primary interaction:

- A slider (0-100) sets "energy level" for the current entry.
- Below baseline (50): the tank drains and darkens — black at the very
  bottom (depressive), through purple, up to blue at baseline.
- Above baseline: the tank fills and warms in color, blending between two
  "flavours" of high energy via a second, vertical slider:
  - happy hype -> warm gold/orange
  - irritable hype -> red/magenta
- Past ~88, the tank visually spills over (drops overflow the top) to
  represent a hype phase that exceeds normal range, rather than just
  capping at 100%.
- A dashed baseline marker sits at the 50% mark, extending slightly past
  the tank's edges, diagram-style.

`index.html` in this repo is the working prototype of the visual — treat it
as the reference implementation for the tank component, not necessarily the
final file structure.

## Planned features (roughly in build order)

1. **Logging** — save a mood entry (energy value, flavour value, optional
   note, timestamp) rather than just a live slider.
2. **History view** — list/calendar of past entries.
3. **Weekly diagram** — aggregate a week of entries into a single chart
   (e.g. energy over time, colored the same way as the tank, so the
   weekly view visually echoes the daily widget).
4. **Diary function** — free-text notes attached to entries, searchable.
5. (Maybe) trends/insights — but keep this descriptive, not diagnostic.
   Never present pattern detection as a clinical claim.

## Tone and framing rules

- This app names things directly (depressive, hype, baseline) rather than
  euphemistically — that's an intentional choice, keep it.
- Never add copy that pathologizes normal mood variation, and never
  present the app's output as a diagnosis or clinical assessment.
- Keep the visual language consistent: the tank/battery metaphor should
  extend into the weekly diagram and history views rather than switching
  to generic bar charts.

## Tech stack

Not yet decided — flag this to the user in the first session rather than
assuming. Reasonable defaults to propose if asked:
- Frontend: vanilla JS/HTML (matches the prototype) or React if the person
  wants component structure for growing views.
- Storage: start with local storage or a local JSON/SQLite file for
  simplicity; only reach for a backend/db once sync across devices matters.
- No framework should be adopted without discussing tradeoffs first, since
  this is a side project meant to stay fun to work on.

## Working conventions

- Commit after each completed subtask, with a clear message.
- Keep the tank component visually isolated (its own file/module) so it
  can be reused unchanged in both the daily entry view and any future
  weekly/summary view.
