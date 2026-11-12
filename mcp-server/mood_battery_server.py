"""
MCP server for Swing — lets Claude read and write mood entries
directly in the app's SQLite database.

Add to your Claude config (claude_desktop_config.json or .mcp.json):

{
  "mcpServers": {
    "swing": {
      "command": "python3",
      "args": ["<path-to-repo>/mcp-server/mood_battery_server.py"]
    }
  }
}
"""

import json
import math
import sqlite3
import os
from collections import Counter
from datetime import date, datetime, timedelta, timezone
try:
    from mcp.server.fastmcp import FastMCP
except (ImportError, ModuleNotFoundError):
    from mcp.server.mcpserver import MCPServer as FastMCP

DB_PATH = os.path.expanduser(
    "~/Library/Application Support/MoodBattery/moodbattery.sqlite"
)

mcp = FastMCP(
    "swing",
    instructions=(
        "Swing is a bipolar mood tracker. Mood ranges 0–10 (0.1 precision) "
        "(0 = deep depressive, 5 = baseline, 10 = peak hype). "
        "Flavour ranges 0.0–1.0 (0 = calm, 0.5 = normal, 1 = irritable; "
        "only meaningful above baseline). "
        "Titles are short mood summaries (2–4 words). "
        "Notes are longer diary text. "
        "When the user describes their mood conversationally, extract mood and flavour "
        "from context and save an entry. Ask to confirm before saving if uncertain. "
        "Each day holds one entry: to change a day that already has one, update it. "
        "Tags are feelings from a fixed list, picked by an on-device model or by hand in the app. "
        "For a summary of a period, take the numbers from range_summary (never count them yourself) "
        "and the text from entries_in_range."
    ),
)

MANUAL_TAG_VERSION = "manual"


def get_db() -> sqlite3.Connection:
    """Opens a connection to the Swing SQLite database with row-factory enabled."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    columns = [r["name"] for r in conn.execute("PRAGMA table_info(moodEntry)")]
    if "localDate" not in columns or "tagModelVersion" not in columns:
        conn.close()
        raise RuntimeError(
            "The Swing database is from an older version of the app — open the Swing app once to migrate it."
        )
    return conn


def parse_timestamp(timestamp: str | None) -> tuple[str, str]:
    """Returns (stored timestamp, calendar day) for a new or changed entry.

    The stored timestamp is always UTC in the one format the app reads ("YYYY-MM-DD HH:MM:SS.mmm"): anything
    else in that column stops the app from loading the diary. An explicit timestamp must be ISO 8601; without
    an offset it is local time. The day is taken as written, so "2026-10-25T23:00:00" belongs to 25 Oct
    whatever the time zone. Without a timestamp it is now, and today in the machine's local zone.
    Raises ValueError for text that isn't a date.
    """
    if timestamp:
        written = datetime.fromisoformat(timestamp.strip().replace("Z", "+00:00"))
    else:
        written = datetime.now().astimezone()
    stored = written.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    return stored, written.strftime("%Y-%m-%d")


def parse_day(value: str) -> str:
    """Checks a YYYY-MM-DD day and returns it; raises ValueError otherwise."""
    return date.fromisoformat(value.strip()).isoformat()


def row_to_dict(row: sqlite3.Row) -> dict:
    """Converts a database row into a plain dictionary with named fields."""
    return {
        "id": row["id"],
        "mood": row["mood"],
        "flavour": row["flavour"],
        "title": row["title"],
        "note": row["note"],
        "timestamp": row["timestamp"],
        "localDate": row["localDate"],
        "tags": entry_tags(row),
        "tagSource": tag_source(row),
    }


def entry_tags(row: sqlite3.Row) -> list[str]:
    """The entry's tags; an unreadable value counts as none."""
    try:
        tags = json.loads(row["tags"] or "[]")
    except ValueError:
        return []
    return [t for t in tags if isinstance(t, str)]


def tag_source(row: sqlite3.Row) -> str | None:
    """Where the tags came from: "by hand", "model", or "model, out of date" when the text changed since."""
    if not entry_tags(row):
        return None
    version = row["tagModelVersion"]
    if version == MANUAL_TAG_VERSION:
        return "by hand"
    return "model" if version else "model, out of date"


def tags_line(entry: dict) -> str | None:
    if not entry["tags"]:
        return None
    return f"Tags: {', '.join(entry['tags'])} ({entry['tagSource']})"


def format_entry(entry: dict, full_note: bool = False) -> str:
    """Formats a mood entry dict into a multi-line string for display, truncating long notes unless `full_note`."""
    parts = [f"[{entry['id']}] {entry['localDate'] or '?'} · {entry['timestamp']}"]
    parts.append(f"  Mood: {entry['mood']:.1f}, Flavour: {entry['flavour']:.2f}")
    if tags_line(entry):
        parts.append(f"  {tags_line(entry)}")
    if entry["title"]:
        parts.append(f"  Title: {entry['title']}")
    if entry["note"]:
        preview = entry["note"] if full_note else entry["note"][:200]
        if not full_note and len(entry["note"]) > 200:
            preview += "…"
        parts.append(f"  Note: {preview}")
    return "\n".join(parts)


@mcp.tool()
def save_mood_entry(
    mood: float,
    flavour: float,
    title: str | None = None,
    note: str | None = None,
    timestamp: str | None = None,
) -> str:
    """Save a new mood entry.

    Args:
        mood: Mood level 0–10, 0.1 precision (0=depressive floor, 5=baseline, 10=peak hype)
        flavour: Mood flavour 0.0–1.0 (0=happy/euphoric, 1=irritable/agitated; matters above baseline)
        title: Short mood summary, 2–4 words (e.g. "rough morning", "elevated")
        note: Longer diary text
        timestamp: ISO 8601 timestamp, local time unless it carries an offset; defaults to now. The entry's
            day is the date as written (e.g. 2026-10-25T23:00:00 is 25 Oct); with no timestamp it is today.

    A day holds one entry: saving to a day that already has one is refused, use update_mood_entry instead.
    """
    if not 0 <= mood <= 10:
        return "Error: mood must be 0–10"
    if not 0 <= flavour <= 1:
        return "Error: flavour must be 0.0–1.0"
    try:
        ts, day = parse_timestamp(timestamp)
    except ValueError:
        return f"Error: timestamp must be ISO 8601 (e.g. 2026-10-25T21:00:00), got '{timestamp}'"

    db = get_db()
    existing = db.execute("SELECT id FROM moodEntry WHERE localDate = ? ORDER BY id", (day,)).fetchone()
    if existing:
        db.close()
        return (
            f"Error: {day} already has an entry (#{existing['id']}). "
            "Each day holds one entry — change it with update_mood_entry."
        )
    cursor = db.execute(
        "INSERT INTO moodEntry (mood, flavour, title, note, timestamp, localDate) VALUES (?, ?, ?, ?, ?, ?)",
        (mood, flavour, title, note, ts, day),
    )
    db.commit()
    entry_id = cursor.lastrowid
    db.close()
    return f"Saved entry #{entry_id} — mood {mood:.1f}, flavour {flavour:.2f}, title: {title or '(none)'}"


@mcp.tool()
def update_mood_entry(
    entry_id: int,
    mood: float | None = None,
    flavour: float | None = None,
    title: str | None = None,
    note: str | None = None,
    timestamp: str | None = None,
) -> str:
    """Update an existing mood entry. Only provided fields are changed.

    Args:
        entry_id: The entry's ID
        mood: New mood level 0–10
        flavour: New flavour 0.0–1.0
        title: New title
        note: New note text
        timestamp: New ISO 8601 timestamp (also moves the entry to the date as written, if that day is free)

    Changing the title or note marks model-made tags as out of date, as the app does; tags picked by hand stay.
    """
    db = get_db()
    row = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    if not row:
        db.close()
        return f"Error: entry #{entry_id} not found"

    updates = {}
    if mood is not None:
        if not 0 <= mood <= 10:
            db.close()
            return "Error: mood must be 0–10"
        updates["mood"] = mood
    if flavour is not None:
        if not 0 <= flavour <= 1:
            db.close()
            return "Error: flavour must be 0.0–1.0"
        updates["flavour"] = flavour
    if title is not None:
        updates["title"] = title
    if note is not None:
        updates["note"] = note
    text_changed = any(k in updates and updates[k] != row[k] for k in ("title", "note"))
    if text_changed and row["tagModelVersion"] != MANUAL_TAG_VERSION:
        updates["tagModelVersion"] = None
    if timestamp is not None:
        try:
            ts, day = parse_timestamp(timestamp)
        except ValueError:
            db.close()
            return f"Error: timestamp must be ISO 8601 (e.g. 2026-10-25T21:00:00), got '{timestamp}'"
        taken = db.execute(
            "SELECT id FROM moodEntry WHERE localDate = ? AND id != ?", (day, entry_id)
        ).fetchone()
        if taken:
            db.close()
            return f"Error: {day} already has an entry (#{taken['id']}); each day holds one entry."
        updates["timestamp"] = ts
        updates["localDate"] = day

    if not updates:
        db.close()
        return "No fields to update"

    set_clause = ", ".join(f"{k} = ?" for k in updates)
    values = list(updates.values()) + [entry_id]
    db.execute(f"UPDATE moodEntry SET {set_clause} WHERE id = ?", values)
    db.commit()

    updated = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    db.close()
    return f"Updated entry #{entry_id}:\n{format_entry(row_to_dict(updated))}"


@mcp.tool()
def list_recent_entries(count: int = 10) -> str:
    """List recent mood entries, newest first.

    Args:
        count: Number of entries to return (default 10, max 100)
    """
    count = min(count, 100)
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry ORDER BY timestamp DESC LIMIT ?", (count,)
    ).fetchall()
    db.close()

    if not rows:
        return "No entries found."

    entries = [format_entry(row_to_dict(r)) for r in rows]
    return f"{len(rows)} most recent entries:\n\n" + "\n\n".join(entries)


@mcp.tool()
def get_entry(entry_id: int) -> str:
    """Get a single mood entry by ID with full details.

    Args:
        entry_id: The entry's ID
    """
    db = get_db()
    row = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    db.close()

    if not row:
        return f"Entry #{entry_id} not found."

    entry = row_to_dict(row)
    parts = [f"Entry #{entry['id']}"]
    parts.append(f"Day: {entry['localDate'] or '(not set)'}")
    parts.append(f"Timestamp: {entry['timestamp']}")
    parts.append(f"Mood: {entry['mood']:.1f}")
    parts.append(f"Flavour: {entry['flavour']:.2f}")
    parts.append(tags_line(entry) or "Tags: (none)")
    parts.append(f"Title: {entry['title'] or '(none)'}")
    parts.append(f"Note: {entry['note'] or '(none)'}")
    return "\n".join(parts)


@mcp.tool()
def delete_entry(entry_id: int) -> str:
    """Delete a mood entry.

    Args:
        entry_id: The entry's ID
    """
    db = get_db()
    row = db.execute("SELECT * FROM moodEntry WHERE id = ?", (entry_id,)).fetchone()
    if not row:
        db.close()
        return f"Entry #{entry_id} not found."

    db.execute("DELETE FROM moodEntry WHERE id = ?", (entry_id,))
    db.commit()
    db.close()
    return f"Deleted entry #{entry_id}."


@mcp.tool()
def search_entries(query: str, limit: int = 20) -> str:
    """Search entries by title or note text.

    Args:
        query: Text to search for in titles and notes
        limit: Max results (default 20)
    """
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry WHERE title LIKE ? OR note LIKE ? ORDER BY timestamp DESC LIMIT ?",
        (f"%{query}%", f"%{query}%", limit),
    ).fetchall()
    db.close()

    if not rows:
        return f"No entries matching '{query}'."

    entries = [format_entry(row_to_dict(r)) for r in rows]
    return f"{len(rows)} entries matching '{query}':\n\n" + "\n\n".join(entries)


@mcp.tool()
def entries_for_date(date: str) -> str:
    """Get all entries for a specific date.

    Args:
        date: Date in YYYY-MM-DD format
    """
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry WHERE localDate = ? ORDER BY timestamp",
        (date,),
    ).fetchall()
    db.close()

    if not rows:
        return f"No entries for {date}."

    entries = [format_entry(row_to_dict(r)) for r in rows]
    return f"{len(rows)} entries for {date}:\n\n" + "\n\n".join(entries)


@mcp.tool()
def mood_summary(days: int = 7) -> str:
    """Get a summary of mood over a period — average mood, range, and entry count.

    Args:
        days: Number of days to look back (default 7)
    """
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry WHERE localDate >= date('now', 'localtime', ?) ORDER BY timestamp",
        (f"-{days} days",),
    ).fetchall()
    db.close()

    if not rows:
        return f"No entries in the last {days} days."

    moods = [r["mood"] for r in rows]
    flavours = [r["flavour"] for r in rows]
    avg_mood = sum(moods) / len(moods)
    avg_flavour = sum(flavours) / len(flavours)

    return (
        f"Last {days} days: {len(rows)} entries\n"
        f"Mood — avg: {avg_mood:.1f}, min: {min(moods):.1f}, max: {max(moods):.1f}\n"
        f"Flavour — avg: {avg_flavour:.2f}\n"
        f"Range: {rows[0]['timestamp']} → {rows[-1]['timestamp']}"
    )


# ---------------------------------------------------------------------------------------------------------
# Periods: the numbers and the text for a summary
#
# The bands and the episode rules below repeat the app's, so both tell the same story. Keep them in step with
# Sources/MoodBattery/Tank/MoodState.swift, Models/MoodScale.swift and Models/EpisodeDetector.swift.
# ---------------------------------------------------------------------------------------------------------

EVERYDAY_BANDS = ["very low", "low", "dipping", "balanced", "lifted", "high", "very high"]
BIPOLAR_BANDS = ["severe depression", "moderate depression", "mild depression", "balanced", "hypomania", "mania"]

EPISODE_RULES = {
    # kind: (threshold, tolerated limit on the other side of baseline, shortest span in days, longest gap bridged)
    "depressive": (3.5, 5.5, 14, 2),
    "elevated": (6.5, 4.5, 4, 2),
}
EPISODE_MIN_QUALIFYING_SHARE = 0.7
# A run still open today is reported as forming from this many days, before it is long enough to be an episode.
FORMING_DAYS = {"depressive": 7, "elevated": 2}


def everyday_band(mood: float) -> str:
    if mood < 1.5:
        return "very low"
    if mood < 3:
        return "low"
    if mood < 4.5:
        return "dipping"
    if mood <= 5.5:
        return "balanced"
    if mood < 7:
        return "lifted"
    if mood < 8.5:
        return "high"
    return "very high"


def bipolar_band(mood: float) -> str:
    """The Bipolar UK Mood Scale band, read at the nearest whole number (halves round up, so 8.5 is mania)."""
    nearest = math.floor(mood + 0.5)
    if nearest <= 1:
        return "severe depression"
    if nearest == 2:
        return "moderate depression"
    if nearest == 3:
        return "mild depression"
    if nearest <= 6:
        return "balanced"
    if nearest <= 8:
        return "hypomania"
    return "mania"


def day_moods(rows: list[sqlite3.Row]) -> dict[date, tuple[float, float]]:
    """Average mood and flavour per logged day."""
    by_day: dict[date, list[sqlite3.Row]] = {}
    for row in rows:
        try:
            by_day.setdefault(date.fromisoformat(row["localDate"]), []).append(row)
        except ValueError:
            continue
    return {
        day: (sum(r["mood"] for r in group) / len(group), sum(r["flavour"] for r in group) / len(group))
        for day, group in by_day.items()
    }


def classify_day(moods: dict[date, tuple[float, float]], day: date, kind: str) -> str:
    """How a day relates to a run of `kind`: "qualifying", "gap" (unlogged or near baseline) or "breaking"."""
    threshold, tolerated, _, _ = EPISODE_RULES[kind]
    if day not in moods:
        return "gap"
    mood = moods[day][0]
    if kind == "depressive":
        if mood < threshold:
            return "qualifying"
        return "breaking" if mood > tolerated else "gap"
    if mood >= threshold:
        return "qualifying"
    return "breaking" if mood < tolerated else "gap"


def make_run(moods: dict[date, tuple[float, float]], days: list[date], kind: str, start: int, end: int) -> dict:
    logged = [moods[d][0] for d in days[start:end + 1] if d in moods]
    return {
        "kind": kind,
        "start": days[start],
        "end": days[end],
        "days": end - start + 1,
        "logged_days": len(logged),
        "average_mood": sum(logged) / len(logged),
    }


def forming_run(moods: dict[date, tuple[float, float]], today: date | None = None) -> dict | None:
    """The run still open today that is on its way to an episode but not long enough yet, as in the app.

    Days since the last logged one count as gaps. None when nothing is forming, including when the open run is
    already a full episode (detect_episodes reports that).
    """
    if not moods:
        return None
    today = today or datetime.now().astimezone().date()
    first = min(moods)
    if first > today:
        return None
    days = [first + timedelta(days=i) for i in range((today - first).days + 1)]
    for kind in ("elevated", "depressive"):
        _, _, min_days, max_gap = EPISODE_RULES[kind]
        kinds = [classify_day(moods, day, kind) for day in days]
        start = 0
        while start < len(kinds):
            if kinds[start] != "qualifying":
                start += 1
                continue
            last_qualifying, qualifying, gap_run, ended = start, 1, 0, False
            for j in range(start + 1, len(kinds)):
                if kinds[j] == "qualifying":
                    last_qualifying, qualifying, gap_run = j, qualifying + 1, 0
                elif kinds[j] == "gap":
                    gap_run += 1
                    if gap_run > max_gap:
                        ended = True
                        break
                else:
                    ended = True
                    break
            span = last_qualifying - start + 1
            share_met = qualifying >= EPISODE_MIN_QUALIFYING_SHARE * span
            if not ended:
                if span >= min_days and share_met:
                    break
                if span >= FORMING_DAYS[kind] and share_met:
                    return make_run(moods, days, kind, start, last_qualifying)
                start += 1
            else:
                start = last_qualifying + 1 if span >= min_days and share_met else start + 1
    return None


def format_forming(run: dict) -> str:
    """Names the state and counts days, as the app's caption does, with no target number."""
    word = "an elevated run" if run["kind"] == "elevated" else "a low run"
    return (
        f"Forming now: day {run['days']} of {word}, from {run['start']} "
        f"({run['logged_days']} days logged, average mood {run['average_mood']:.1f}). "
        "Not an episode yet; it only counts days."
    )


def detect_episodes(moods: dict[date, tuple[float, float]]) -> list[dict]:
    """Sustained depressive or elevated runs, by the same rules as the app's diagram bands.

    A run starts and ends on a day past the threshold, bridges a couple of unlogged or near-baseline days,
    stops at a day on the other side, and must be long enough and at least 70% days past the threshold.
    """
    if not moods:
        return []
    first, last = min(moods), max(moods)
    days = [first + timedelta(days=i) for i in range((last - first).days + 1)]
    episodes = []
    for kind, (threshold, tolerated, min_days, max_gap) in EPISODE_RULES.items():
        below = kind == "depressive"

        def classify(day: date) -> str:
            if day not in moods:
                return "gap"
            mood = moods[day][0]
            if below:
                if mood < threshold:
                    return "qualifying"
                return "breaking" if mood > tolerated else "gap"
            if mood >= threshold:
                return "qualifying"
            return "breaking" if mood < tolerated else "gap"

        kinds = [classify(day) for day in days]
        start = 0
        while start < len(kinds):
            if kinds[start] != "qualifying":
                start += 1
                continue
            last_qualifying, qualifying, gap_run = start, 1, 0
            for j in range(start + 1, len(kinds)):
                if kinds[j] == "qualifying":
                    last_qualifying, qualifying, gap_run = j, qualifying + 1, 0
                elif kinds[j] == "gap":
                    gap_run += 1
                    if gap_run > max_gap:
                        break
                else:
                    break
            span = last_qualifying - start + 1
            if span >= min_days and qualifying >= EPISODE_MIN_QUALIFYING_SHARE * span:
                logged = [moods[d][0] for d in days[start:last_qualifying + 1] if d in moods]
                episodes.append({
                    "kind": kind,
                    "start": days[start],
                    "end": days[last_qualifying],
                    "days": span,
                    "logged_days": len(logged),
                    "average_mood": sum(logged) / len(logged),
                })
                start = last_qualifying + 1
            else:
                start += 1
    return sorted(episodes, key=lambda e: e["start"])


def format_episode(episode: dict) -> str:
    return (
        f"{episode['kind']}: {episode['start']} to {episode['end']} "
        f"({episode['days']} days, {episode['logged_days']} logged, average mood {episode['average_mood']:.1f})"
    )


def markers_between(db: sqlite3.Connection, first: str, last: str) -> list[sqlite3.Row]:
    """Markers placed by hand on the diagram between two days; none when the app hasn't created the table yet."""
    if not db.execute("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'marker'").fetchone():
        return []
    return db.execute(
        "SELECT * FROM marker WHERE localDate BETWEEN ? AND ? ORDER BY localDate, id", (first, last)
    ).fetchall()


def format_marker(marker: sqlite3.Row) -> str:
    return f"{marker['localDate']} · {marker['kind']}: {marker['label']}"


def parse_range(start: str, end: str | None) -> tuple[str, str]:
    """Checks a day range and returns it; `end` defaults to today. Raises ValueError with a readable message."""
    try:
        first = parse_day(start)
        last = parse_day(end) if end else datetime.now().astimezone().strftime("%Y-%m-%d")
    except ValueError:
        raise ValueError("Error: dates must be YYYY-MM-DD") from None
    if first > last:
        raise ValueError("Error: start must not be after end")
    return first, last


@mcp.tool()
def entries_in_range(start: str, end: str | None = None, full_notes: bool = True) -> str:
    """Get every entry between two days, oldest first, with tags and (by default) the whole note.

    Use this for the text behind a summary of a period. For the numbers, use range_summary.

    Args:
        start: First day, YYYY-MM-DD
        end: Last day, YYYY-MM-DD, inclusive (default today)
        full_notes: False cuts each note to 200 characters
    """
    try:
        first, last = parse_range(start, end)
    except ValueError as error:
        return str(error)
    db = get_db()
    rows = db.execute(
        "SELECT * FROM moodEntry WHERE localDate BETWEEN ? AND ? ORDER BY localDate, timestamp", (first, last)
    ).fetchall()
    markers = markers_between(db, first, last)
    db.close()

    if not rows:
        return f"No entries from {first} to {last}."
    entries = [format_entry(row_to_dict(r), full_note=full_notes) for r in rows]
    header = f"{len(rows)} entries from {first} to {last}:"
    if markers:
        header += "\nMarkers in this period: " + "; ".join(format_marker(m) for m in markers)
    return header + "\n\n" + "\n\n".join(entries)


@mcp.tool()
def range_summary(start: str, end: str | None = None) -> str:
    """The numbers for a period, worked out exactly: days logged, mood average and range, days per mood band
    (everyday words and the Bipolar UK Mood Scale), how often each tag appears, and the episodes that overlap it.

    Quote these numbers in a summary; don't count from the entries. Descriptive only, not a diagnosis.

    Args:
        start: First day, YYYY-MM-DD
        end: Last day, YYYY-MM-DD, inclusive (default today)
    """
    try:
        first, last = parse_range(start, end)
    except ValueError as error:
        return str(error)
    db = get_db()
    all_rows = db.execute("SELECT * FROM moodEntry ORDER BY localDate, timestamp").fetchall()
    markers = markers_between(db, first, last)
    db.close()

    first_day, last_day = date.fromisoformat(first), date.fromisoformat(last)
    rows = [r for r in all_rows if first <= r["localDate"] <= last]
    if not rows:
        return f"No entries from {first} to {last}."

    moods = {d: m for d, m in day_moods(rows).items()}
    total_days = (last_day - first_day).days + 1
    values = [m for m, _ in moods.values()]
    lowest, highest = min(moods, key=lambda d: moods[d][0]), max(moods, key=lambda d: moods[d][0])
    everyday = Counter(everyday_band(m) for m in values)
    bipolar = Counter(bipolar_band(m) for m in values)
    elevated_flavours = [f for m, f in moods.values() if m >= 7]
    tag_counts = Counter(tag for r in rows for tag in entry_tags(r))
    untagged = sum(1 for r in rows if not entry_tags(r))
    # Episodes are found over the whole diary, so one that began before the period is still seen whole.
    episodes = [e for e in detect_episodes(day_moods(all_rows)) if e["start"] <= last_day and e["end"] >= first_day]

    lines = [
        f"{first} to {last}: {len(moods)} of {total_days} days logged",
        f"Mood — average {sum(values) / len(values):.1f}, lowest {moods[lowest][0]:.1f} ({lowest}), "
        f"highest {moods[highest][0]:.1f} ({highest})",
        "Days per band, everyday words — " + ", ".join(f"{b}: {everyday[b]}" for b in EVERYDAY_BANDS if everyday[b]),
        "Days per band, Bipolar UK Mood Scale — " + ", ".join(f"{b}: {bipolar[b]}" for b in BIPOLAR_BANDS if bipolar[b]),
    ]
    if elevated_flavours:
        irritable = sum(1 for f in elevated_flavours if f > 0.65)
        calm = sum(1 for f in elevated_flavours if f < 0.35)
        lines.append(
            f"Flavour on the {len(elevated_flavours)} days at 7 or above — irritable: {irritable}, "
            f"calm: {calm}, in between: {len(elevated_flavours) - irritable - calm}"
        )
    if tag_counts:
        lines.append("Tags (days) — " + ", ".join(f"{tag}: {n}" for tag, n in tag_counts.most_common()))
    if untagged:
        lines.append(f"Entries without tags: {untagged}")
    if episodes:
        lines.append("Episodes overlapping this period (same rules as the app's diagram bands):")
        lines += [f"  {format_episode(e)}" for e in episodes]
    else:
        lines.append("No sustained episodes overlap this period.")
    forming = forming_run(day_moods(all_rows))
    if forming and forming["start"] <= last_day and forming["end"] >= first_day:
        lines.append(format_forming(forming))
    if markers:
        lines.append("Markers placed by hand in this period:")
        lines += [f"  {format_marker(m)}" for m in markers]
    return "\n".join(lines)


@mcp.tool()
def mood_episodes() -> str:
    """List every sustained mood episode in the diary, oldest first, by the same rules as the bands the app
    draws on its diagram: a depressive run of at least 14 days below 3.5, or an elevated run of at least
    4 days at 6.5 or above, allowing a couple of unlogged or near-baseline days in between. Also reports a run
    that is forming now (2 elevated or 7 low days in, still open today), as the app's dashed band does.

    Descriptive only: these are patterns in the logged numbers, not a diagnosis.
    """
    db = get_db()
    rows = db.execute("SELECT * FROM moodEntry ORDER BY localDate, timestamp").fetchall()
    db.close()

    moods = day_moods(rows)
    episodes = detect_episodes(moods)
    forming = forming_run(moods)
    lines = [f"{len(episodes)} episodes:"] + [format_episode(e) for e in episodes] if episodes else ["No sustained episodes in the diary."]
    if forming:
        lines.append(format_forming(forming))
    return "\n".join(lines)


@mcp.tool()
def list_markers() -> str:
    """List the markers placed by hand on the app's diagram (medication changes, appointments, other events),
    oldest first. They are the user's own record of what happened when, not inferred.
    """
    db = get_db()
    markers = markers_between(db, "0000-01-01", "9999-12-31")
    db.close()
    if not markers:
        return "No markers on the diagram."
    return f"{len(markers)} markers:\n" + "\n".join(format_marker(m) for m in markers)


if __name__ == "__main__":
    mcp.run()
