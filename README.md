# Swing

**v1.1.8**

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
your mood over time across week, month, and year scales.

## Features

- **Gauge logging** — drag to set mood (0-10), slide to set flavour
  (calm to irritable), add a title and note, save to local database.
- **History list** — scrollable, mood-colored entries with Dock-style
  magnification on hover and liquid glass effects (macOS 26+).
- **Mood diagram** — mood over time with a mood-colored line. Week, month,
  and year scales with pinch-to-zoom, paging, and continuous lines across
  page boundaries. The year scale shows weekly averages. Detected mood
  episodes appear as tinted bands behind the line: depressive (mood below
  3.5 for at least 14 days) and elevated (6.5 or above for at least 4 days),
  following DSM-5 bipolar II durations. Runs tolerate a couple of unlogged or
  near-baseline days, but a logged day on the opposite side ends them, and at
  least 70% of the span must be qualifying days.
- **Entry detail panel** — tap any entry to view and inline-edit all
  fields (double-click mood, flavour, title, or note). Shows the entry's tags,
  an Auto-tag button, and (in the PMDD lens) a "Period started on this day"
  checkbox. Delete entries here.
- **On-device AI tagging** — Gemma 4 E2B, run locally through llama.cpp,
  reads an entry's title and note and picks up to four tags from a fixed list
  of feelings (low, flat, anxious, calm, hopeful, energised…): one or two for
  the earlier part of the day and one or two for the end, so mixed days keep
  both sides. Tag one entry from the detail panel or all of them from the
  toolbar, with a progress bar and time estimate. Tags appear as coloured
  chips in the history list and the panel. Editing a note marks its tags out
  of date, and changing the model or prompt version re-queues every entry.
  The model never sees the mood rating, so tags stay an independent reading
  of the text.
- **Keyboard navigation** — up/down arrows flick through entries, ESC
  closes the detail panel or cancels an edit. The selected entry is shown
  on the gauge, the diagram scrolls to its week, and its dot gets a ring
  that fades between entries.
- **Retrospective entries** — tap an empty date in the week diagram to log
  for a past day. One entry per day is enforced.
- **Markdown import** — import `.md` diary files with a preview sheet.
  Parses dates and mood/flavour from field lines (`Mood: 4.8. Flavour: 0.4`,
  one per line or together) or estimates them from the text. Days that
  already have an entry are skipped.
- **Search** — type words in the toolbar search field to find diary entries
  by title or note (case and accent-insensitive, all words must match). The
  database is searched, matching dots on the diagram get a ring while the rest
  dim, the history list narrows to the matches, and the matched words are
  highlighted in the detail panel. Up/down arrows step through the matches,
  Return jumps to the newest one.
- **Data export** — export all entries (with their tags) as CSV or JSON from
  the toolbar menu, which also has "Clear all entries". Debug builds add a
  dummy-data seeder there.
- **MCP server** — Python server for Claude integration (log, query,
  update, delete entries).

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
| `tagModelVersion` | text | Model and prompt version behind `tags`; null if never tagged or out of date |

Table `periodStart` holds one `localDate` (`yyyy-MM-dd`, primary key) per
logged period start, for the PMDD lens.

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
| `get_entry`           | `entry_id`                                             | Full details of one entry                |
| `delete_entry`        | `entry_id`                                             | Delete an entry                          |
| `search_entries`      | `query`, `limit?` (default 20)                         | Search titles and notes                  |
| `entries_for_date`    | `date` (`YYYY-MM-DD`)                                  | All entries for a day                    |
| `mood_summary`        | `days?` (default 7)                                    | Average, range and count over a period   |

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
  Weekly/                    Mood diagram (week/month/year)
  Persistence/               SQLite store, database manager
  Import/                    Markdown diary importer
  Export/                    CSV and JSON export
  Models/                    MoodEntry, mood scale, episode detection,
                             per-day/week aggregation, menstrual cycle calendar
mcp-server/                  Python MCP server (reads/writes the same SQLite file)
project.yml                  XcodeGen spec
```

## License

[MIT](LICENSE)
