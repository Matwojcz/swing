# Next Actions

## For Mat

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

- **iPhone port.** Plan in `docs/IOS_PORT_PLAN.md` (iPhone 15 Pro, sync through an iCloud Drive folder). Next is
  phase 0: spikes for free signing, SideStore refresh and the shared folder, plus a quick test of Apple's built-in
  model against diary text, and whether a free-signed app may read sleep from Apple Health.

- **Pick your own backup folder (setting in the app).** The second backup copy goes to a fixed path for now,
  `iCloud Drive/Swing/database-backups`, which only exists on a Mac with iCloud Drive. Before the cross-platform
  work (iPhone, Android, other people using Swing), replace it with a "Choose backup folder…" setting that
  remembers the folder (a security-scoped bookmark, so it also works sandboxed), shows where copies go and when
  the last one was made, and can be turned off. It should share the folder choice with sync, which needs the
  same kind of user-picked folder (`docs/IOS_PORT_PLAN.md`). Until then the path is in
  `DatabaseManager.iCloudBackupDirectory`.

## Ideas, not decided

- Quick check-ins on the phone (several per day, the day drawn as a range). Changes the one-entry-per-day model.
- Year in pixels: one coloured square per day, filterable by tag.
- Touch ID lock.
