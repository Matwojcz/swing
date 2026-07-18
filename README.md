# Mood battery

An interactive mood tracker with a battery/tank visual, built as a personal
side project. See `CLAUDE.md` for the full concept and planned feature set.

## Status

Prototype only. `index.html` is a self-contained, working version of the
tank visual — open it directly in a browser to try it.

## Native app

The macOS app lives under `Sources/MoodBattery`, targets macOS 12+, and
uses [GRDB](https://github.com/groue/GRDB.swift) for local SQLite storage.
The Xcode project is generated from `project.yml` via
[XcodeGen](https://github.com/yonaskolb/XcodeGen) rather than committed
directly, so it stays merge-conflict-free.

```
brew install xcodegen
xcodegen generate
open MoodBattery.xcodeproj
```

## Next steps

Open this folder in Claude Code (`claude` from the terminal) and start
with something like: "let's decide on a data model for a mood entry, then
scaffold logging."
