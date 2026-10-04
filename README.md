# Swing

A personal, visual mood tracker for macOS. Not a clinical tool — a way to
log and reflect on mood state over time, using direct language (depressive,
hype, baseline) rather than euphemisms.

## How it works

A semicircular gauge is the main interaction. Drag the needle to set your
energy level (0-10, half-point steps):

- The arc sweeps from black (depressive floor) through purple, up to blue
  at baseline (5), then through green into gold/orange or red/magenta above.
- A vertical flavour slider sets the tone of elevated mood: calm on one
  end, irritable on the other.
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
  episodes (sustained depressive or elevated stretches) appear as tinted
  bands behind the line.
- **Entry detail panel** — tap any entry to view and inline-edit all
  fields (double-click mood, flavour, title, or note). Delete entries here.
- **Keyboard navigation** — up/down arrows flick through entries, ESC
  closes the detail panel or cancels an edit. The selected entry is shown
  on the gauge, the diagram scrolls to its week, and its dot gets a ring
  that fades between entries.
- **Retrospective entries** — tap an empty date in the week diagram to log
  for a past day. One entry per day is enforced.
- **Markdown import** — import `.md` diary files with a preview sheet.
  Parses dates and mood/flavour from fields or text sentiment.
- **Data export** — export all entries as CSV or JSON from the toolbar menu,
  which also has dummy-data seeding and "Clear all entries" for development.
- **MCP server** — Python server for Claude integration (log, query,
  update, delete entries).

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (to build from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

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

Build and run from Xcode (Cmd+R). The app stores data in a local SQLite
database — no account or network connection needed.

Run `xcodegen generate` again after adding or removing source files. The
project has no test target yet.

## Database

SQLite file at `~/Library/Application Support/MoodBattery/moodbattery.sqlite`,
table `moodEntry`, migrated by GRDB on launch:

| Column      | Type     | Notes                                                    |
|-------------|----------|----------------------------------------------------------|
| `id`        | integer  | Auto-incremented primary key                             |
| `mood`      | double   | 0-10 in 0.5 steps, baseline 5                            |
| `flavour`   | double   | 0-1, calm (0) to irritable (1)                           |
| `title`     | text     | Optional short summary                                   |
| `note`      | text     | Optional diary text                                      |
| `timestamp` | datetime | UTC instant the entry was logged                         |
| `localDate` | text     | `yyyy-MM-dd` calendar day the entry belongs to           |

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

## Project structure

```
Sources/MoodBattery/
  ContentView.swift          Main layout (editor + diagram | history)
  MoodBatteryApp.swift       App entry point
  Entry/                     Gauge editor, text fields
  Tank/                      Gauge view, spark effects, mood colors
  History/                   Entry list, detail panel
  Weekly/                    Mood diagram (week/month/year)
  Persistence/               SQLite store, database manager
  Import/                    Markdown diary importer
  Export/                    CSV and JSON export
  Models/                    MoodEntry, mood scale, episode detection,
                             per-day/week aggregation
mcp-server/                  Python MCP server (reads/writes the same SQLite file)
project.yml                  XcodeGen spec
```

## License

[MIT](LICENSE)
