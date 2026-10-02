# Next Actions

## Diagram highlight & smooth swaps on arrow-key navigation

When cycling through entries with ↑/↓ on the main view, the diagram
should visually track the selection:

1. **Highlight the current entry's dot on the diagram.** A ring or
   halo around the dot that matches `MoodColor.color(mood:flavour:)`
   for that entry. Should be visible on the week scale (dots are
   present); month scale also has dots so highlight there too;
   year scale uses weekly-averaged dots — probably highlight the
   week chunk the entry falls into.

2. **Fade the highlight between dots when navigating.** When ↑/↓
   moves selection from entry A to entry B, the highlight on A
   should fade out and the one on B should fade in. Use
   `withAnimation(.easeInOut)` around the state change; SwiftUI's
   implicit transitions handle the crossfade.

3. **Smooth diagram page swap.** The diagram already jumps to the
   week containing the selected entry via `scrollToDate`. Verify
   the scroll animation is smooth; if not, wrap the `currentPage`
   assignment inside `MoodDiagramView.onChange(of: scrollToDate)`
   in `withAnimation(.easeInOut(duration: 0.25))`.

### Where to touch
- `MoodDiagramView.swift` — accept a `highlightedEntry: MoodEntry?`
  parameter. In `drawSeries`, when a dot's `date` matches the
  highlighted entry's day, draw an extra outer ring at a larger
  radius with matching colour.
- `ContentView.swift` — pass `selectedEntry` into `MoodDiagramView`
  as `highlightedEntry`.

### Doc comments
- New `highlightedEntry` param on `MoodDiagramView` needs a comment.
- Update `drawSeries` comment to mention the highlight ring.

---

## Year-view month labels: duplicates and missing month

In `MoodDiagramView.swift` the `.year` case of `dayLabels(for:)` samples
at a fixed 30-day stride (`monthIdx * 30` for `monthIdx` in 0..<12).
Real months average ~30.44 days, so after a few cycles the sampled day
sits in the same calendar month as the previous sample (May shows twice;
Feb or similar gets skipped), and the loop never reaches day 331-364 so
the final month (e.g. Sep) is never labelled.

**Fix:** walk through `days` once, emit a label the first time each
(year, month) pair appears. Keeps the equal-width layout via
`.frame(maxWidth: .infinity)`. Up to 13 labels possible (a 365-day span
can cross 13 calendar months) — still readable.

### Where to touch
- `MoodDiagramView.swift` — replace the `.year` branch in `dayLabels`
  with a scan over `days` producing month-start dates.

### Doc comments
- Update `dayLabels(for:)` comment to describe the new year-case behaviour.
