# Next Actions

## For Mat

- **24 May 2026 has two entries** (#603: mood 2.0, no note; #609: mood 3.0 with a note). The diagram draws their
  average. Delete one in the app.
- **Restart the diary chat's Swing connection** to pick up the new MCP server (one entry per day, checked
  timestamps, tags, period tools).

## To confirm

- **Fact extraction.** Gemma pulls facts out of each entry into their own table, shown as a row in the panel and
  a Patterns view. Which facts? Starting list: sleep, weed, alcohol, medication changes, exercise, people,
  physical symptoms, work stress.
- **Date-range summaries.** Now possible through the diary chat: the MCP server has `entries_in_range` (the text)
  and `range_summary` (exact numbers, tags, episodes). Try it on October there first. An in-app Gemma summary
  only matters for people without that setup, so it moves to v2.0 if it's still wanted.
- **Search by meaning.** Later and separate from exact search. Either Gemma writes themes per entry, or a small
  embedding model.

## Decided, ready to start

- **Pattern forming.** Agreed design in `docs/PATTERN_FORMING.md`: a dashed band and a "Day 3 of an elevated
  run" caption for a run that hasn't reached full length yet; also reported by the MCP server. Small:
  `EpisodeDetector` returns the open run, the diagram gets one more band style. Keep the Python copy in step.
- **Markers on the diagram.** Hand-placed markers (date, label, kind: medication, appointment, other) drawn as a
  dashed vertical line with a label at every scale. Clicking one shows the 30 days before and after (average,
  days logged, days per band), worked out by the app and worded as what changed, not why. Added by right-click
  on a day or from the entry panel. One new table; include markers in the MCP range tools; sync to the phone.
- **Automatic backups before sync.** A dated copy of the database on launch (keep the last few). Export leaves
  out period days and can't be imported back, and the sync work will restructure the database.
- **iPhone port.** Plan in `docs/IOS_PORT_PLAN.md` (iPhone 15 Pro, sync through an iCloud Drive folder). Next is
  phase 0: spikes for free signing, SideStore refresh and the shared folder, plus a quick test of Apple's built-in
  model against diary text, and whether a free-signed app may read sleep from Apple Health.

## Ideas, not decided

- Quick check-ins on the phone (several per day, the day drawn as a range). Changes the one-entry-per-day model.
- Year in pixels: one coloured square per day, filterable by tag.
- Touch ID lock.
