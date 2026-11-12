# Swing

**v1.4**

A personal, visual mood tracker for macOS. Not a clinical tool — a way to
log and reflect on mood state over time. Labels use neutral everyday words
(very low, balanced, very high) by default; the opt-in Bipolar lens switches
them to the direct terms of the Bipolar UK Mood Scale (depression, hypomania,
mania). An on-device model reads each diary note and tags how the day felt,
without anything leaving the Mac.

## How it works

A semicircular gauge is the main interaction. Drag the needle to set your
mood (0-10, in 0.1 steps):

- The arc sweeps from black (depressive floor) through purple, up to blue
  at baseline (5), then through green into gold/orange or red/magenta above.
- A vertical flavour slider sets the tone of elevated mood: calm on one
  end, irritable on the other.
- The lens turret beside the mood label switches the wording: everyday words,
  the Bipolar lens, whose bands follow the Bipolar UK Mood Scale at the
  nearest whole number (8.5 and up reads as mania) and keep the everyday
  "dipping" and "lifted" inside its wide balanced band (6.3 reads "balanced,
  lifted"), or the PMDD lens, which
  places each day in the menstrual cycle from logged period start days and
  marks low or irritable days as premenstrual or non-cycle related.
- Past 8.8, a redline zone with spark particles marks the hype range —
  like a tachometer needle entering a danger zone.

Each entry is saved with an optional title and free-text note. The history
list shows all entries with mood-colored indicators, and a diagram plots
your mood over time across week, month, and year scales, with detected
episodes and a run that is forming; hover a dot to compare the days
around it.

## Features

- **Gauge logging** — drag to set mood (0-10), slide to set flavour
  (calm to irritable), add a title and note, save to local database.
- **History list** — scrollable, mood-colored entries with Dock-style
  magnification on hover and liquid glass effects (macOS 26+).
- **Mood diagram** — mood over time with a mood-colored line. Week, month,
  and year scales with pinch-to-zoom, paging, and continuous lines across
  page boundaries. The year scale shows weekly averages, each with a faint
  bar from the week's lowest to highest day so the real range stays in view.
  The week scale spreads days out, which makes the same moves look gentler,
  so it draws distances from baseline 1.5 times larger, easing off towards the
  ends (the diagram has no scale; values and the hover card are unchanged). Detected mood
  episodes appear as tinted bands behind the line: depressive (mood below
  3.5 for at least 14 days) and elevated (6.5 or above for at least 4 days),
  following DSM-5 bipolar II durations. Runs tolerate a couple of unlogged or
  near-baseline days, but a logged day on the opposite side ends them, and at
  least 70% of the span must be qualifying days.
  A run that is still open today but not long enough yet shows as a dashed,
  unfilled band, from 2 days for an elevated run or 7 for a low one, with a
  caption under the diagram such as "Day 3 of an elevated run" (in the
  Bipolar lens, "Day 3 in the hypomania range"). It fills in on the day it
  becomes an episode, or disappears without a trace if the run fades. It
  only counts days: no alerts, advice or predictions.
- **Hover a dot** — rest the pointer on a dot (it doesn't react while
  scrolling or passing over) and a small card shows that day's mood, band and tags, and a
  line when the day stands out: "Lowest since 26 Oct" or "Highest since 14
  Jul" (only when it's the lowest or highest for at least two weeks). On the
  year scale the dot is a week: its average and its lowest and highest day.
- **Entry detail panel** — tap any entry to view and inline-edit all
  fields (double-click mood, flavour, title, note, or the tags). Shows the
  entry's tags, an Auto-tag button, and (in the PMDD lens) a "Period started
  on this day" checkbox. Delete entries here.
- **On-device AI tagging** — Gemma 4 E2B, run locally through llama.cpp,
  reads an entry's title and note and picks up to four tags from a fixed list
  of feelings (low, flat, anxious, calm, hopeful, energised…): one or two for
  the earlier part of the day and one or two for the end, so mixed days keep
  both sides. Tag one entry from the detail panel or all of them from the
  toolbar, with a progress bar and time estimate. Tags appear as coloured
  chips in the history list and the panel. Editing a note marks its tags out
  of date, and changing the model or prompt version re-queues every entry.
  When the model gets an entry wrong, double-click its tags in the panel to
  remove some or add others from the same list, up to four. Tags picked by
  hand are marked with a small hand icon, and "Auto-tag all" leaves them
  alone; the panel's own Auto-tag button still replaces them if asked.
  The model never sees the mood rating, so tags stay an independent reading
  of the text. It takes about 3 GB of memory while loaded and is freed after
  five minutes without tagging.
- **Keyboard navigation** — up/down arrows flick through entries, ESC
  closes the detail panel or cancels an edit. The selected entry is shown
  on the gauge, the diagram scrolls to its week, and its dot gets a ring
  that fades between entries.
- **Retrospective entries** — tap an empty date in the week diagram to log
  for a past day; the "Logging for…" line has a cancel button, and ESC
  cancels it too. One entry per day is enforced.
- **Import** — the toolbar Import menu reads three kinds of file, each
  shown in a review sheet before anything is saved. A Markdown diary (`.md`):
  dates and mood/flavour come from field lines (`Mood: 4.8. Flavour: 0.4`, one
  per line or together) or are estimated from the text. A Swing export (`.csv`
  or `.json`): entries come back as exported, with their day and tags (and
  whether the tags were picked by hand); rows with a missing or out-of-range
  value are left out and counted. Days that already have an entry are skipped.
- **Search** — the toolbar search field has two kinds of search, and every
  word must match. Plain words find tags ("lonely") and mood band names in the
  current lens ("lifted", "hypomania") and nothing else, so low means low days,
  never "a low hum" in a note. Words in quote marks ("Dark Souls") find titles
  and notes only, as a phrase, once the closing quote is typed. The two can be
  combined: lonely "Iris". Matching
  is by whole words (case and accents don't matter, "lift" never finds
  "lifted"). Two-word band names count as one: very low finds very low days,
  and low finds only low days. In the Bipolar lens balanced covers the whole 4
  to 6 band, balanced lifted and balanced dipping just its edges; in the PMDD
  lens the cycle phases (premenstrual, period, follicular, luteal) are
  searchable too. Flavour isn't searched. Matching dots on the diagram get a
  ring while the rest dim, and the history list narrows to the matches. Each
  row shows why it matched (an outlined tag, a highlighted title, or the
  matching line of the note or band name), and the detail panel highlights the
  same. Up/down arrows step through the matches, Return jumps to the newest one.
- **Data export and backups** — export all entries (with their tags and where
  the tags came from) as CSV or JSON from the toolbar menu; Import reads both
  back. The same menu which also opens the two backup folders (see
  Database) and has "Clear all entries". Debug builds add a dummy-data
  seeder there.
- **MCP server** — Python server for Claude integration (log, query,
  update, delete entries; exact numbers, tags and episodes for a period).
  The app reads the diary again whenever you return to it, and an edit
  saves only the field that changed, so changes made through the server
  while Swing is open are picked up and never overwritten.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (to build from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- For AI tagging: the Gemma 4 E2B model file
  (`gemma-4-E2B-it-Q4_K_M.gguf`, about 3.1 GB, e.g. from
  [unsloth/gemma-4-E2B-it-GGUF](https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF))
  at `~/Models/`. The path is fixed in `TaggingController.swift` for now; the
  rest of the app works without it.

## Install

```bash
# Clone the repo
git clone https://github.com/matwojcz/swing.git
cd swing

# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project and open it
xcodegen generate
open Swing.xcodeproj
```

Build and run from Xcode (Cmd+R). On the first build Xcode asks you to trust
the LLM.swift package's Swift macro; choose Trust & Enable. The app stores data
in a local SQLite database — no account or network connection needed.

Run `xcodegen generate` again after adding or removing source files. The
project has no test target yet.

## Database

SQLite file at `~/Library/Application Support/MoodBattery/moodbattery.sqlite`,
migrated by GRDB on launch. Table `moodEntry`:

| Column      | Type     | Notes                                                    |
|-------------|----------|----------------------------------------------------------|
| `id`        | integer  | Auto-incremented primary key                             |
| `mood`      | double   | 0-10 in 0.1 steps, baseline 5                            |
| `flavour`   | double   | 0-1, calm (0) to irritable (1)                           |
| `title`     | text     | Optional short summary                                   |
| `note`      | text     | Optional diary text                                      |
| `timestamp` | datetime | UTC instant the entry was logged                         |
| `localDate` | text     | `yyyy-MM-dd` calendar day the entry belongs to           |
| `tags`      | text     | JSON array of AI tag names, `[]` when untagged           |
| `tagModelVersion` | text | Model and prompt version behind `tags`, `manual` if picked by hand; null if never tagged or out of date |

Swing copies the database once a day into `Backups/` next to it
(`moodbattery-yyyy-MM-dd.sqlite`, taken on launch and when you return to the
app, before any migration) and keeps the last 14. "Show backups in Finder" in
the toolbar menu opens the folder. To restore one, quit Swing and copy it over
`moodbattery.sqlite`. Export leaves out period days and markers, so the
backups are the only complete copies.

A second copy goes off the Mac on every launch, into
`iCloud Drive/Swing/database-backups` (`moodbattery-yyyy-MM-dd-HHmmss.sqlite`,
newest 30 kept), if that folder exists. The path is fixed for now; a "pick your
own backup folder" setting will replace it. "Show iCloud backups in Finder"
opens it.

Table `periodStart` holds one `localDate` (`yyyy-MM-dd`, primary key) per
logged period start, for the PMDD lens. Table `marker` (`id`,
`localDate`, `label`, `kind`) holds day markers from a parked feature: the app
no longer shows or adds them, but keeps the rows, and the MCP server lists
them.

## MCP server (optional)

The included MCP server lets Claude read and write mood entries directly.
Requires Python 3 and the `mcp` package (`pip install mcp`).

Add to your Claude config (`.mcp.json` or `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "swing": {
      "command": "python3",
      "args": ["<path-to-repo>/mcp-server/mood_battery_server.py"]
    }
  }
}
```

Tools:

| Tool                  | Arguments                                              | Purpose                                  |
|-----------------------|--------------------------------------------------------|------------------------------------------|
| `save_mood_entry`     | `mood`, `flavour`, `title?`, `note?`, `timestamp?`     | Log an entry (defaults to now)           |
| `update_mood_entry`   | `entry_id`, plus any of the fields above               | Change fields of an entry                |
| `list_recent_entries` | `count?` (default 10, max 100)                         | Newest entries first                     |
| `get_entry`           | `entry_id`                                             | Full details of one entry, with tags     |
| `delete_entry`        | `entry_id`                                             | Delete an entry                          |
| `search_entries`      | `query`, `limit?` (default 20)                         | Search titles and notes                  |
| `entries_for_date`    | `date` (`YYYY-MM-DD`)                                  | All entries for a day                    |
| `mood_summary`        | `days?` (default 7)                                    | Average, range and count over a period   |
| `entries_in_range`    | `start`, `end?` (default today), `full_notes?`         | Every entry in a period, whole notes     |
| `range_summary`       | `start`, `end?` (default today)                        | Exact numbers for a period (see below)   |
| `mood_episodes`       | none                                                   | Every episode, and a run forming now     |
| `list_markers`        | none                                                   | Day markers (parked feature)             |

The server follows the app's rules. A day holds one entry, so saving to a day
that already has one is refused. Timestamps must be ISO 8601 (local time
unless they carry an offset) and are stored in the one format the app reads.
Changing a title or note marks model-made tags as out of date. Entries are
shown with their tags and where the tags came from (model, by hand, or out of
date).

`range_summary` gives the numbers a written summary should quote, worked out
rather than estimated: days logged, mood average and range, days per band (in
everyday words and on the Bipolar UK Mood Scale), tag counts, and the episodes
that overlap the period, and the markers in it (`entries_in_range` lists them
too). Episodes and bands use the same rules as the app
(`MoodState`, `MoodScale`, `EpisodeDetector`), repeated in Python: change them
in both places.

The server needs the app to have run once so the database exists and is migrated.

## Time zones

Each entry stores its calendar day (`localDate`, `yyyy-MM-dd`) next to the UTC
`timestamp`. The day is fixed when the entry is logged, so an entry saved at
23:00 stays on that day when British Summertime ends or you change time zone.
All grouping (diagram, episodes, one-entry-per-day check) uses `localDate`.
Rows inserted straight into SQLite without it are backfilled from their
timestamp the next time the app reads them.

## Tech stack

- **SwiftUI** — native macOS interface
- **SQLite via [GRDB.swift](https://github.com/groue/GRDB.swift)** — local
  persistence
- **XcodeGen** — `project.yml` generates the Xcode project, keeping it
  merge-conflict-free
- **[LLM.swift](https://github.com/eastriverlee/LLM.swift) / llama.cpp** —
  on-device inference on Metal, with JSON-schema-constrained output so the
  model can only answer with tags from the list
- **Gemma 4 E2B** (Google, Apache-2.0) — the tagging model

## Project structure

```
Sources/MoodBattery/
  ContentView.swift          Main layout (editor + diagram | history)
  MoodBatteryApp.swift       App entry point (frees the model before quitting)
  AI/                        Tag set, prompt, llama.cpp classifier, tagging controller
  Lens/                      Lens choice, lens turret, cycle environment
  Entry/                     Gauge editor, text fields
  Tank/                      Gauge view, spark effects, mood colors
  History/                   Entry list, detail panel
  Weekly/                    Mood diagram (week/month/year), hover card
  Persistence/               SQLite store, database manager
  Import/                    Markdown diary and CSV/JSON export importers
  Export/                    CSV and JSON export
  Models/                    MoodEntry, mood scale, episode detection,
                             per-day/week aggregation, menstrual cycle calendar
mcp-server/                  Python MCP server (reads/writes the same SQLite file)
project.yml                  XcodeGen spec
```

## License

[MIT](LICENSE)
