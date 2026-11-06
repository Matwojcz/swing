# Next Actions

## To confirm

- **Fact extraction.** Gemma pulls facts out of each entry into their own table, shown as a row in the panel and
  a Patterns view. Which facts? Starting list: sleep, weed, alcohol, medication changes, exercise, people,
  physical symptoms, work stress.
- **Date-range summaries.** Liked as the strongest use of the model. Test first: run Gemma on October and read the
  result, and try facts on about 20 entries. Diary text stays local.
- **Search by meaning.** Later and separate from exact search. Either Gemma writes themes per entry, or a small
  embedding model.

- **Quote marks in search.** `"low"` would search the note text for a word that's otherwise a tag or band, so a day
  where you wrote "lonely" without the tag can still be found.

## Decided, ready to start

- **iPhone port.** Plan in `docs/IOS_PORT_PLAN.md` (iPhone 15 Pro, sync through an iCloud Drive folder). Next is
  phase 0: spikes for free signing, SideStore refresh and the shared folder, plus a quick test of Apple's built-in
  model against diary text.
