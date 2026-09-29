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
