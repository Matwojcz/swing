# Swing

A personal, visual mood tracker for macOS. Not a clinical tool — a way to
log and reflect on mood state over time, using direct language (depressive,
hype, baseline) rather than euphemisms.

## How it works

A semicircular gauge is the main interaction. Drag the needle to set your
energy level (0-100):

- The arc sweeps from black (depressive floor) through purple, up to blue
  at baseline (50), then into gold/orange or red/magenta above baseline.
- A vertical flavour slider sets the tone of elevated mood: calm on one
  end, irritable on the other.
- Past ~88, a redline zone with spark particles marks the hype range —
  like a tachometer needle entering a danger zone.

Each entry is saved with an optional title and free-text note. The history
list shows all entries with mood-colored indicators, and a diagram plots
your mood over time across week, month, and year scales.

## Features

- **Gauge logging** — drag to set mood (0-100), slide to set flavour
  (calm to irritable), add a title and note, save to local database.
- **History list** — scrollable, mood-colored entries with Dock-style
  magnification on hover and liquid glass effects (macOS 26+).
- **Mood diagram** — energy over time with mood-colored line. Week, month,
  and year scales with pinch-to-zoom, paging, and continuous lines across
  page boundaries.
- **Entry detail panel** — tap any entry to view and inline-edit all
  fields (double-click mood, flavour, title, or note). Delete entries here.
- **Keyboard navigation** — arrow keys to flick through entries in the
  detail panel, ESC to close or cancel an edit. Selecting an entry scrolls
  the diagram to its week.
- **Retrospective entries** — tap an empty date in the week diagram to log
  for a past day. One entry per day is enforced.
- **Markdown import** — import `.md` diary files with a preview sheet.
  Parses dates and mood/flavour from fields or text sentiment.
- **Data export** — export all entries as CSV or JSON.
- **MCP server** — Python server for Claude integration (log, query,
  update, delete entries).

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (to build from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Install

```bash
# Clone the repo
git clone https://github.com/matwojcz/mood-battery.git
cd mood-battery

# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project and open it
xcodegen generate
open MoodBattery.xcodeproj
```

Build and run from Xcode (Cmd+R). The app stores data in a local SQLite
database — no account or network connection needed.

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
  Models/                    MoodEntry data model
```

## License

[MIT](LICENSE)
