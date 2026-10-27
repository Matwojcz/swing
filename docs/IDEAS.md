# Feature ideas

A backlog of ideas not yet scheduled. Each is a sketch to react to, not a
commitment. Keep it on the mainline so ideas aren't trapped on feature
branches.

---

## Reflection space — give meaning to a stretch of days

**What:** a place to step back and reflect on *several days together*, rather
than one entry at a time.

- **Select multiple days** — pick a span (or a handful) of days, e.g. from the
  diagram timeline or the history list.
- **A reflection panel opens over the centre** — same overlay style as the
  existing `EntryDetailPanel` (dimmed backdrop, panel floating above the
  editor/diagram), with a free-text input where the user writes what those
  days meant to them ("this week I was coming down off…", "rough patch but I
  noticed…").
- **Linked back to the days** — once saved, the reflection is reachable from
  within the entries of the days it covers (an indicator / link in the detail
  panel of each of those days), so a day knows it belongs to a reflection.

**Why:** mood tracking is data; meaning-making is the therapeutic part.
A span-level reflection is where patterns get named — exactly the kind of
thing a therapist asks for.

### Placeholder / stretch — AI-assisted reflection (local model)

Once the on-device model (Phase 1+ of the AI plan) is working, it could offer
to **generate a gentle reflection about the selected span** — summarising the
arc of the week from the entries and tags, as a prompt for the user's own
reflection, not a verdict.

- **Fully offline**, same local model, same privacy guarantees.
- **User-initiated and optional** — never automatic; the user asks for it.
- **Framed as reflection, not advice or diagnosis** — a mirror, not a clinician.
  Wording to be reviewed with the therapist (ties into the safety release
  gate). Must never alarm or over-interpret, especially on low stretches.
- The user's own text stays primary; any AI text is clearly marked as
  machine-generated and editable/dismissable.

### Rough design notes (for later)

- **Data model:** a `Reflection` record (own text + optional AI text +
  created date) linked to a set of days — many-days-to-one-reflection. New
  table + join, or a day-range on the reflection.
- **Surfacing:** small marker on entries whose day falls in a reflection;
  tapping opens the reflection panel.
- **Scope:** span need not be contiguous — allow a selection of days, not just
  a continuous range, if it's not much more work.
